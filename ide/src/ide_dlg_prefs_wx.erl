%% =====================================================================
%% @author
%% @copyright
%% @title
%% @version
%% @doc 
%% @end
%% =====================================================================
  
-module(ide_dlg_prefs_wx).
  
-include_lib("wx/include/wx.hrl").
  
%% wx_object
-behaviour(wx_object).
-export([init/1,
         terminate/2,
         code_change/3,
         handle_info/2,
         handle_call/3,
         handle_cast/2,
         handle_event/2]).
         
%% API
-export([start/1]).

%% Server state
-record(state, {frame, pref_panel, pref}).        

-define(PREF_GENERAL, 1).
-define(PREF_EDITOR, 2).
-define(PREF_CONSOLE, 3).
-define(PREF_DEBUG, 4).
  

%% =====================================================================
%% Client API
%% =====================================================================
  
%% =====================================================================
%% @doc Start a preference pane instance.
  
start(Config) ->
	wx_object:start_link(?MODULE, Config, []).
  

%% =====================================================================
%% Callback functions
%% =====================================================================
 
%% =====================================================================
%% @doc Initialise the preference pane.
  
init(Config) ->
  Parent = proplists:get_value(parent, Config),
	Frame = wxFrame:new(Parent, ?wxID_ANY, "Preferences", []),
  
  ToolBar = wxFrame:createToolBar(Frame, [{style, ?wxTB_TEXT}]),
  wxToolBar:setToolBitmapSize(ToolBar, {48,48}),
  %% Id, text, bitmap path, args, add seperator
  Tools = [{?PREF_GENERAL,  "General", "prefs/general.png",    [],  false},
           {?PREF_EDITOR, "Editor", "prefs/editor.png",   [],  false},
           {?PREF_CONSOLE, "Console", "prefs/console.png",   [],  false},
           {?PREF_DEBUG, "Debugger", "prefs/debug.png",   [],  false}],

  AddTool = fun({Id, Tooltip, Filename, Args, true}) ->
            wxToolBar:addRadioTool(ToolBar, Id, Tooltip, wxBitmap:new(wxImage:new(ide_lib_widgets:rc_dir(Filename))), Args),
            wxToolBar:addSeparator(ToolBar);
           ({Id, Tooltip, Filename, Args, _}) ->
            wxToolBar:addRadioTool(ToolBar, Id, Tooltip, wxBitmap:new(wxImage:new(ide_lib_widgets:rc_dir(Filename))), Args)
            end,       

  [AddTool(Tool) || Tool <- Tools],

  wxToolBar:realize(ToolBar),
  wxFrame:connect(Frame, command_menu_selected, [{userData, Tools}]),
  
  Panel = wxPanel:new(Frame),
  PanelSz = wxBoxSizer:new(?wxVERTICAL),
  wxPanel:setSizer(Panel, PanelSz),
    
  State = #state{frame=Frame, pref_panel={Panel, PanelSz}},
  
  %% Load the first preference pane
  PrefPane = load_pref("general", State),
  
  wxSizer:add(PanelSz, PrefPane, [{proportion,1}, {flag, ?wxEXPAND}]),
	wxSizer:setSizeHints(PanelSz, Frame),
  wxSizer:layout(PanelSz),
  
  wxFrame:centre(Frame),
  wxFrame:show(Frame),
  
  {Frame, State#state{pref=PrefPane}}.

handle_info(Msg, State) ->
  io:format("Got Info (prefs) ~p~n",[Msg]),
  {noreply,State}.
    
handle_call(_Msg, _From, State) ->
  {reply,{error, nyi}, State}.
    
handle_cast(Msg, State) ->
  io:format("Got cast ~p~n",[Msg]),
  {noreply,State}.
    
%% Catch menu clicks
handle_event(#wx{id=Id, event=#wxCommand{type=command_menu_selected}, userData=Tb}, 
             State=#state{frame=Frame, pref_panel={Panel,Sz}, pref=Pref}) ->
  {_,Str,_,_,_} = proplists:lookup(Id,Tb),
  wxSizer:detach(Sz, Pref),
  wx_object:call(Pref, shutdown),
  wxPanel:hide(Panel), %% Hide whilst loading, and show when complete to stop flicker
  NewPref = load_pref(Str, State),
  wxSizer:add(Sz, NewPref, [{proportion,1}, {flag, ?wxEXPAND}]),
  wxSizer:fit(Sz, Frame),
  wxSizer:layout(Sz),
  wxPanel:layout(Panel),
  wxPanel:show(Panel),
  {noreply, State#state{pref=NewPref}};
    
%% Event catchall for testing
handle_event(Ev = #wx{}, State) ->
  io:format("Prefs event catchall: ~p\n", [Ev]),
  {noreply, State}.
    
code_change(_, _, State) ->
  {stop, not_yet_implemented, State}.

terminate(_Reason, #state{frame=Frame}) ->
  wxFrame:destroy(Frame).
    

%% =====================================================================
%% Internal functions
%% =====================================================================

%% =====================================================================
%% @doc Load a preference pane.

load_pref(Pref, #state{pref_panel={Panel,_Sz}}) ->
  ModStr = "ide_pref_" ++ string:to_lower(Pref) ++ "_wx",
  Mod = list_to_atom(ModStr),
  Mod:start([{parent, Panel}]).