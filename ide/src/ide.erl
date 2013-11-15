%% =====================================================================
%% @author
%% @copyright
%% @title
%% @version
%% @doc This module is responsible for building all of the GUI components. 
%% @end
%% =====================================================================

-module(ide).

-include_lib("wx/include/wx.hrl").
-include("ide.hrl").

%% wx_object
-behaviour(wx_object).
-export([init/1, terminate/2,  code_change/3,
         handle_info/2, handle_call/3, handle_cast/2, handle_event/2]).
	
%% API			 
-export([start/0, set_title/1, toggle_menu_group/2]).

%% Server state
-record(state, {frame,
                % env,                                           %% The wx environment
                workspace :: wxAuiNotebook:wxAuiNotebook(),    %% Notebook
                utilities,                                     %% The utilities pane
                left_pane,                                     %% The test pane
                workspace_manager,                             %% Tabbed UI manager for editors
                sash_v :: wxSpliiterWindow:wxSplitterWindow(), %% The vertical splitter
                sash_h :: wxSpliiterWindow:wxSplitterWindow(), %% The horizontal splitter
                sash_v_pos :: integer(),
                sash_h_pos :: integer(),
                menu_ets
                }).
								
%% Macros
-define(DEFAULT_FRAME_WIDTH,  1100).
-define(DEFAULT_FRAME_HEIGHT, 680).
-define(DEFAULT_UTIL_HEIGHT,  200).
-define(DEFAULT_TEST_WIDTH,   200).
-define(SASH_VERTICAL, 1).
-define(SASH_HORIZONTAL, 2).
-define(SASH_VERT_DEFAULT_POS, 215).
-define(SASH_HOR_DEFAULT_POS, -200).
-define(ID_DIALOG_TEXT, 9001).
-define(LABEL_HIDE_UTIL, "Hide Utilities Pane\tShift+Alt+U").
-define(LABEL_SHOW_UTIL, "Show Utilities Pane\tShift+Alt+U").
-define(FRAME_TITLE, "Erlang IDE").


%% =====================================================================
%% Client API
%% =====================================================================

%% =====================================================================
%% @doc Start the erlang IDE

start() ->
  start([]).

start(Args) ->
	wx_object:start({local, ?MODULE}, ?MODULE, Args, [{debug, [log]}]).
	%% Trap the error {error,{already_started,Pid()}} to prevent the app from
	%% being opened twice.


%% =====================================================================
%% @doc Update the frame's title.

set_title(Title) ->
	wx_object:cast(?MODULE, {title, Title}).


%% =====================================================================
%% @doc Enable/disable a menu group

toggle_menu_group(Mask, Toggle) ->
	wx_object:cast(?MODULE, {toggle_menu_group, Mask, Toggle}).
	
		
%% =====================================================================
%% Callback functions
%% =====================================================================

init(Options) ->
	wx:new(Options),
	WxEnv = wx:get_env(),
	process_flag(trap_exit, true),
  
  % wxSystemOptions:setOption("window-default-variant", ?wxWINDOW_VARIANT_SMALL),

	Frame = wxFrame:new(wx:null(), ?wxID_ANY, "Erlang IDE", [{size,{?DEFAULT_FRAME_WIDTH,?DEFAULT_FRAME_HEIGHT}}]),
	wxFrame:connect(Frame, close_window),
	wxFrame:setMinSize(Frame, {300,200}),
	
	%% Load modules that should be started by OTP Application and not here
  sys_pref_manager:start([{wx_env, WxEnv}]),
  ProjDir = sys_pref_manager:get_preference(project_directory),
  case filelib:is_dir(ProjDir) of
    false ->
      file:make_dir(ProjDir);
    true ->
      ok
  end,
	project_manager:start([{frame, Frame}, {wx_env, WxEnv}]),

	FrameSizer = wxBoxSizer:new(?wxVERTICAL),
	wxWindow:setSizer(Frame, FrameSizer),
	
	SplitterStyle = case os:type() of
		{_, darwin} -> ?wxSP_3DSASH bor ?wxSP_LIVE_UPDATE;
		_ -> ?wxSP_3DSASH
	end,
	SplitterTopBottom = wxSplitterWindow:new(Frame, [{id, ?SASH_HORIZONTAL},
		{style, SplitterStyle}]),
	SplitterLeftRight = wxSplitterWindow:new(SplitterTopBottom, [{id, ?SASH_VERTICAL},
		{style, SplitterStyle}]),	

	wxSplitterWindow:setSashGravity(SplitterTopBottom, 0.5),
	wxSplitterWindow:setSashGravity(SplitterLeftRight, 0.60),

	wxSizer:add(FrameSizer, SplitterTopBottom, [{flag, ?wxEXPAND}, {proportion, 1}]),

	%% Status bar %%
	StatusBar = ide_status_bar:start([{parent, Frame}]),

	%% Menubar %%
  {Menu, MenuEts} = ide_menu:create([{parent, Frame}]),

	wxSizer:add(FrameSizer, StatusBar, [{flag, ?wxEXPAND},
                                        {proportion, 0}]),

	Workspace = create_workspace(SplitterLeftRight),

	%% The left window
	LeftWindow = create_left_window(Frame, SplitterLeftRight),

	%% The bottom pane/utility window
	Utilities = create_utils(SplitterTopBottom),

	wxSplitterWindow:splitVertically(SplitterLeftRight, LeftWindow, Workspace,
	                  [{sashPosition, ?SASH_VERT_DEFAULT_POS}]),

	wxSplitterWindow:splitHorizontally(SplitterTopBottom, SplitterLeftRight, Utilities,
                  [{sashPosition, ?SASH_HOR_DEFAULT_POS}]),

	wxSizer:layout(FrameSizer),
	wxFrame:center(Frame),
	wxFrame:show(Frame),

	wxSplitterWindow:setSashGravity(SplitterTopBottom, 1.0), % Only the top window grows on resize
	wxSplitterWindow:setSashGravity(SplitterLeftRight, 0.0), % Only the right window grows

  wxSplitterWindow:connect(Frame, command_splitter_sash_pos_changed,  [{userData, SplitterLeftRight}]),
  wxSplitterWindow:connect(Frame, command_splitter_doubleclicked),

	%% Testing accelerator table
	% AccelTab = wxAcceleratorTable:new(1,
	% [wxAcceleratorEntry:new([{flags, ?wxACCEL_NORMAL}, {keyCode, ?WXK_SPACE}, {cmd, ?MENU_ID_FONT}])]),
	% wxFrame:setAcceleratorTable(Frame, AccelTab),
  
  %% Toggle menu defaults
  toggle_menu_group(?MENU_GROUP_NOTEBOOK_EMPTY bor 
                    ?MENU_GROUP_PROJECTS_EMPTY, false),

  {Frame, #state{
						frame=Frame,
            left_pane=LeftWindow,
            utilities=Utilities,
            sash_v_pos=?SASH_VERT_DEFAULT_POS,
            sash_h_pos=?SASH_HOR_DEFAULT_POS,
            sash_v=SplitterLeftRight,
            sash_h=SplitterTopBottom,
						workspace=Workspace,
            menu_ets=MenuEts
            }}.


%% Deal with trapped exit signals
handle_info({'EXIT',_, wx_deleted}, State) ->
  io:format("Got Info 1~n"),
  {noreply,State};
handle_info({'EXIT',_, shutdown}, State) ->
  io:format("Got Info 2~n"),
  {noreply,State};
handle_info({'EXIT',A, normal}, State) ->
	io:format("IN IDE INFO~n"),
  io:format("Got Info 3~n~p~n", [A]),
  {noreply,State};
handle_info(Msg, State) ->
  io:format("Got Info ~p~n",[Msg]),
  {noreply,State}.

handle_call(frame, _From, State) ->
	{reply, State#state.frame, State}.

handle_cast({toggle_menu_group, Mask, Toggle}, State=#state{frame=Frame, menu_ets=MenuEts}) ->
  MenuBar = wxFrame:getMenuBar(Frame),
  ets:foldl(
  fun({Id,_}, DontCare) ->
    DontCare;
  ({Id,_,Options}, DontCare) ->
    case proplists:get_value(group, Options) of
      undefined -> ok;
      Groups ->
        toggle_menu_item(MenuBar, wxFrame:getToolBar(Frame), Mask, Id, Groups, Toggle)
    end,
    DontCare
  end, notused, MenuEts),
	{noreply, State};
handle_cast({title, Title}, State=#state{frame=Frame}) ->
	Str = case Title of
		[] -> ?FRAME_TITLE;
		T -> Title ++ " - " ++ ?FRAME_TITLE
	end,
	wxFrame:setTitle(Frame, Str),
  {noreply, State}.

%% =====================================================================
%% Event handlers
%%
%% =====================================================================

%% Window close event
handle_event(#wx{event=#wxClose{}}, State) ->
  io:format("~p Closing window ~n",[self()]),
  {stop, normal, State};


%% =====================================================================
%% Sash drag handlers
%%
%% =====================================================================

%% Vertical sash dragged
handle_event(_W=#wx{id=?SASH_VERTICAL, event=#wxSplitter{type=command_splitter_sash_pos_changed}=_E}, State) ->
  Pos = wxSplitterWindow:getSashPosition(State#state.sash_v),
  %% Don't save the pos if the sash is dragged to zero, as the sash
  %% will revert to the middle when shown again (on mac definitely,
	%% probably on all platforms, THIS SHOULD BE CHECKED AGAIN on R16B01 and wxWidgets 2.9.4)
  if
    Pos =:= 0 ->
    	NewPos = State#state.sash_v_pos;
    true ->
    	NewPos = Pos
    end,
  {noreply, State#state{sash_v_pos=NewPos}};

%% Horizontal sash dragged
handle_event(_W=#wx{id=?SASH_HORIZONTAL, event=#wxSplitter{type=command_splitter_sash_pos_changed}=_E}, State) ->
  Pos = wxSplitterWindow:getSashPosition(State#state.sash_h),
  if
    Pos =:= 0 ->
    	NewPos = State#state.sash_h_pos;
    true ->
    	NewPos = Pos
  end,
  wxWindow:refresh(State#state.sash_v),
  wxWindow:update(State#state.sash_v),
  {noreply, State#state{sash_h_pos=NewPos}};

handle_event(#wx{event = #wxSplitter{type = command_splitter_doubleclicked} = _E}, State) ->
  io:format("Sash double clicked ~n"),
  {noreply, State};


%% =====================================================================
%% Menu handlers
%%
%% =====================================================================

%% See ticket #5
%% Although a temporary fix has been implemented for ticket #5, using this handler
%% would be the preferred option
handle_event(#wx{id=Id, event=#wxMenu{type=menu_close}}, State) ->
  ide_status_bar:set_text({field, help}, ?STATUS_BAR_HELP_DEFAULT),
{noreply, State};

%% Handle menu highlight events
handle_event(#wx{id=Id, userData={ets_table, TabId}, event=#wxMenu{type=menu_highlight}}, State) ->
	ide_status_bar:set_text({field, help}, "testing"),
  {noreply, State};

%% First handle the sub-menus
handle_event(E=#wx{id=Id, userData={theme_menu,Menu}, event=#wxCommand{type=command_menu_selected}},
             State) ->
	editor_ops:set_theme(Menu),
	{noreply, State};

handle_event(E=#wx{id=Id, userData=Menu, event=#wxCommand{type=command_menu_selected}},
             State) when Id >= ?MENU_ID_TAB_WIDTH_LOWEST,
						 Id =< ?MENU_ID_TAB_WIDTH_HIGHEST  ->
  doc_manager:apply_to_all_documents(fun editor:set_tab_width/2, [list_to_integer(wxMenu:getLabel(Menu, Id))]),
  sys_pref_manager:set_preference(tab_width, wxMenu:getLabel(Menu, Id)),
	{noreply, State};
handle_event(#wx{event=#wxCommand{type=command_menu_selected},id=?MENU_ID_FULLSCREEN=Id},
						 State=#state{frame=Frame}) ->
	IsFullScreen = wxFrame:isFullScreen(Frame),
	wxFrame:showFullScreen(Frame, not IsFullScreen, [{style, ?wxFULLSCREEN_NOBORDER}]),
	Label = case IsFullScreen of
		true -> "Enter Fullscreen";
		false -> "Exit Fullscreen"
	end,
	ide_menu:update_label(wxFrame:getMenuBar(Frame), Id, Label ++ "\tCtrl+Alt+F"),
	{noreply, State};	
handle_event(#wx{event=#wxCommand{type=command_menu_selected},id=?MENU_ID_HIDE_TEST=Id},
						 State=#state{frame=Frame, sash_v=V, left_pane=LeftPane, workspace=Ws, sash_v_pos=VPos}) ->
   Str = case wxSplitterWindow:isSplit(V) of
       true -> wxSplitterWindow:unsplit(V,[{toRemove, LeftPane}]), "Show Left Pane\tShift+Alt+T";
       false -> wxSplitterWindow:splitVertically(V, LeftPane, Ws, [{sashPosition, VPos}]), "Hide Left Pane\tShift+Alt+T"
   end,
	 ide_menu:update_label(wxFrame:getMenuBar(Frame), Id, Str),
	{noreply, State};
handle_event(#wx{event=#wxCommand{type=command_menu_selected},id=?MENU_ID_HIDE_UTIL=Id},
						 State=#state{frame=Frame, sash_h=H, sash_v=V, utilities=Utils, sash_h_pos=HPos}) ->
	IsShown = wxSplitterWindow:isShown(Utils),
	case wxSplitterWindow:isSplit(H) of
		true -> ok;
		false -> 
			wxSplitterWindow:splitHorizontally(H, V, Utils, [{sashPosition, HPos}]),
			ide_menu:update_label(wxFrame:getMenuBar(Frame), Id, ?LABEL_HIDE_UTIL)
	end,
	case IsShown of
		true -> 
			wxSplitterWindow:unsplit(H,[{toRemove, Utils}]),
			ide_menu:update_label(wxFrame:getMenuBar(Frame), Id, ?LABEL_SHOW_UTIL);
		false -> ok
	end,
	{noreply, State};
handle_event(#wx{event=#wxCommand{type=command_menu_selected},id=?MENU_ID_MAX_EDITOR},
						 State=#state{sash_h=H, sash_v=V, utilities=Utils, left_pane=LeftPane,
						 							sash_h_pos=HPos, sash_v_pos=VPos, workspace=Ws, frame=Frame}) ->
  wxFrame:freeze(Frame),
	Fun = fun(false, false, false) -> %% Restore
		wxSplitterWindow:splitHorizontally(H, V, Utils, [{sashPosition, HPos}]),
		wxSplitterWindow:splitVertically(V, LeftPane, Ws, [{sashPosition, VPos}]);
	(false, _, true) ->
		wxSplitterWindow:splitHorizontally(H, V, Utils, [{sashPosition, HPos}]),
		maximise;
	(_,_,_) -> maximise %% Unsplit both, even if already unsplit
	end,
	case Fun(wxSplitterWindow:isSplit(H), wxSplitterWindow:isSplit(V), wxSplitterWindow:isShown(Utils)) of
		maximise -> 
			wxSplitterWindow:unsplit(H,[{toRemove, Utils}]),
			wxSplitterWindow:unsplit(V,[{toRemove, LeftPane}]);
		_ -> ok
	end,
  wxFrame:thaw(Frame),
	{noreply, State};
handle_event(#wx{event=#wxCommand{type=command_menu_selected},id=?MENU_ID_MAX_UTIL},
						 State=#state{frame=Frame, sash_h=H, sash_v=V, utilities=Utils, left_pane=LeftPane,
						 							sash_h_pos=HPos, sash_v_pos=VPos, workspace=Ws}) ->
  wxFrame:freeze(Frame),
	IsSplit = wxSplitterWindow:isSplit(H),
	IsShown = wxSplitterWindow:isShown(Utils),
	case IsSplit of
		false -> wxSplitterWindow:splitHorizontally(H, V, Utils, [{sashPosition, HPos}]),
						 ide_menu:update_label(wxFrame:getMenuBar(Frame), ?MENU_ID_HIDE_UTIL, ?LABEL_HIDE_UTIL);
		true -> ok
	end,
	case IsSplit =:= IsShown of
		true -> wxSplitterWindow:unsplit(H,[{toRemove, V}]);
		false -> ok
	end,
  wxFrame:thaw(Frame),
	{noreply, State};

%% The menu items from the ETS table
handle_event(E=#wx{id=Id, userData={ets_table, TabId}, event=#wxCommand{type=command_menu_selected}},
             State=#state{frame=Frame}) ->
	Result = case ets:lookup(TabId, Id) of
		[{MenuItemID, {Mod, Func, Args}, Options}] ->
			case proplists:get_value(send_event, Options) of
				undefined -> {ok, {Mod,Func,Args}};
				true -> {ok, {Mod,Func,[E]}}
			end;
		[{_,{Mod,Func,Args}}] ->
			{ok, {Mod,Func,Args}};
		_ -> nomatch
	end,
	case Result of
		{ok,{M,F,A}} -> 
			erlang:apply(M,F,A);
		nomatch -> 
			io:format("Not yet implemented~n")
	end,
  {noreply, State};

%% =====================================================================
%% Other handlers
%%
%% =====================================================================

%% Event catchall for testing
handle_event(Ev, State) ->
  io:format("IDE event catchall: ~p\n", [Ev]),
  {noreply, State}.

code_change(_, _, State) ->
  {stop, not_yet_implemented, State}.

terminate(_Reason, #state{frame=Frame, workspace_manager=Manager}) ->
  io:format("TERMINATE IDE~n"),
  wxFrame:destroy(Frame),
  wx:destroy().


%% =====================================================================
%% Internal functions
%% =====================================================================

%% =====================================================================
%% @doc Create the utilities panel
%% @private

-spec create_utils(Parent) -> Result when
	Parent :: wxWindow:wxWindow(),
	Result :: wxPanel:wxPanel().

create_utils(Parent) ->
	TabbedWindow = tabbed_book:new([{parent, Parent}]),
	
	%% Start the port that communicates with the external ERTs
	% Console = case console_port:start() of
	Console = case console_sup:start_link([]) of
		{error, E} ->
			io:format("PORT SUP Er: ~p~n", [E]),
			lib_widgets:placeholder(TabbedWindow, "Oops, the console could not be loaded.", [{fgColour, ?wxRED}]);
			%% Disable console menu/toolbar items
		Port ->
			io:format("PORT SUP: ~p~n", [Port]),
			C = console_wx:new([{parent, TabbedWindow}]),
      console_port:flush_buffer(), %% Load text received whilst initialising
      console_port:buffer_responses(false), %% The port will now send responses directly to the console
			C
	end,
	tabbed_book:add_page(TabbedWindow, Console, "Console"),
	
	% Observer = ide_observer:start([{parent, TabbedWindow}]),
	% tabbed_book:add_page(TabbedWindow, Observer, "Observer"),

	Dialyser = wxPanel:new(TabbedWindow, []),
	tabbed_book:add_page(TabbedWindow, Dialyser, "Dialyser"),
	
	Debugger = wxPanel:new(TabbedWindow, []),
	tabbed_book:add_page(TabbedWindow, Debugger, "Debugger"),
	
	tabbed_book:set_selection(TabbedWindow, 1),
	
	TabbedWindow.
  

%% =====================================================================
%% @doc

create_left_window(Frame, Parent) ->
	ImgList = wxImageList:new(16,16),
	wxImageList:add(ImgList, wxBitmap:new(wxImage:new("../icons/books-stack.png"))),
	wxImageList:add(ImgList, wxBitmap:new(wxImage:new("../icons/clipboard-task.png"))),
	wxImageList:add(ImgList, wxBitmap:new(wxImage:new("../icons/function.png"))),
	
	Toolbook = tabbed_book_img:new([{parent, Parent}]),
	tabbed_book_img:assign_image_list(Toolbook, ImgList),

	ProjectTrees = ide_projects_tree:start([{parent, Toolbook}, {frame, Frame}]),
	tabbed_book_img:add_page(Toolbook, ProjectTrees, "Projects", [{imageId, 0}]),
	
	TestPanel = wxPanel:new(Toolbook),
	tabbed_book_img:add_page(Toolbook, TestPanel, " Tests ", [{imageId, 1}]),
	
	FunctionsPanel = func_list:start([{parent, Toolbook}]),
	tabbed_book_img:add_page(Toolbook, FunctionsPanel, "Functions", [{imageId, 2}]),
	
	tabbed_book_img:set_selection(Toolbook, 1), %% Default to projects
	Toolbook.


%% =====================================================================
%% @doc

create_workspace(Parent) ->
	doc_manager:start([{parent, Parent}]).


%% =====================================================================
%% @doc Enable/disable a menu item
%% @private

-spec toggle_menu_item(MenuBar, ToolBar, Mask, Id, Groups, Enable) -> 'ok' when
	MenuBar :: wxMenuBar:wxMenuBar(),
  ToolBar :: wxToolBar:wxToolBar(),
	Mask :: integer(), % Defines which groups to affect
	Id :: integer(),	% The menu item id
	Groups :: integer(), % The groups associated to the menu item with Id
	Enable :: boolean().

toggle_menu_item(MenuBar, ToolBar, Mask, Id, Groups, Enable) ->
	case (Mask band Groups) of
		0 -> ok;
		_ ->
			wxMenuItem:enable(wxMenuBar:findItem(MenuBar, Id), [{enable, Enable}]),
      wxToolBar:enableTool(ToolBar, Id, Enable)
	end.
