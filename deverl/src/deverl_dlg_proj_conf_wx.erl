%% =====================================================================
%% This program is free software: you can redistribute it and/or modify
%% it under the terms of the GNU General Public License as published by
%% the Free Software Foundation, either version 3 of the License, or
%% (at your option) any later version.
%% 
%% This program is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU General Public License for more details.
%% 
%% You should have received a copy of the GNU General Public License
%% along with this program.  If not, see <http://www.gnu.org/licenses/>.
%%
%% @author Tom Richmond <tr201@kent.ac.uk>
%% @author Mike Quested <mdq3@kent.ac.uk>
%% @copyright Tom Richmond, Mike Quested 2014
%%
%% @doc Displays the XRC based <em>Project Configuration</em> dialog.
%% Uses default CANCEL/close_window handlers.
%% @end
%% =====================================================================

-module(deverl_dlg_proj_conf_wx).

-include_lib("wx/include/wx.hrl").

%% wx_object
-behaviour(wx_object).
-export([init/1, terminate/2, code_change/3,
	       handle_info/2, handle_call/3, handle_cast/2, handle_event/2]).
				 
%% API
-export([start/1,
         % set_focus/1,
         get_build_config/1, 
         destroy/1]).
			
%% inherited functions
-export([show/1, showModal/1]).
	
%% Server state			 
-record(state, {dialog,
            	  parent,
                desc,
                image_list,
                module :: string(),
                function :: string(),
                args :: string()
            	 }).
 
-define(ID_BITMAP_INFO, 0).
-define(ID_BITMAP_STOP, 1).              
-define(INPUT_MODULE, 0).
-define(INPUT_FUNCTION, 1).
-define(INPUT_ARGS, 2).


%% =====================================================================
%% Client API
%% =====================================================================

start(Parent) ->
  wx_object:start(?MODULE, Parent, []).
	
get_build_config(This) ->
	wx_object:call(This, build_config).
	
destroy(This) ->
	wx_object:call(This, shutdown).
	
	
%% =====================================================================
%% Callback functions
%% =====================================================================
%% @hidden
init(Parent) ->
  % Xrc = wxXmlResource:get(),
  % Dlg = wxDialog:new(),
  % deverl_lib_dlg_wx:win_variant(Dlg),
  % 
  % %% Load XRC (Assumes all XRC handlers init previously)
  % wxXmlResource:loadDialog(Xrc, Dlg, Parent, "project_config"),
  
  wx:batch(fun() -> do_init(Parent) end).

do_init(Parent) ->
  ProjectId = deverl_proj_man:get_active_project(),
  ProjectName = deverl_proj_man:get_name(ProjectId),
  % BuildConfig = deverl_proj_man:get_build_config(ProjectId),
  BuildConfig = [],
  Title = "Project Configuration - " ++ ProjectName,
    
  State = case BuildConfig of
    undefined ->
      #state{module=[], function=[], args=[]};
    _Config ->
      #state{module=io_lib:format("~s", [proplists:get_value(module, BuildConfig, [])]),
             function=io_lib:format("~s", [proplists:get_value(function, BuildConfig, [])]),
             args=io_lib:format("~s", [proplists:get_value(args, BuildConfig, [])])}
  end,
      
	Dialog = wxDialog:new(Parent, ?wxID_ANY, Title, 
		[{style, ?wxDEFAULT_DIALOG_STYLE bor ?wxRESIZE_BORDER bor ?wxDIALOG_EX_METAL}]),
	wxDialog:centre(Dialog),
	
	case os:type() of
		{_, darwin} ->
			wxPanel:setWindowVariant(Dialog, ?wxWINDOW_VARIANT_SMALL);
		 _ -> ok
	end,
	
  LRSizer = wxBoxSizer:new(?wxHORIZONTAL),
  wxPanel:setSizer(Dialog, LRSizer),
  wxSizer:addSpacer(LRSizer, 20),

  VertSizer = wxBoxSizer:new(?wxVERTICAL),
  
	%% Header
  wxSizer:addSpacer(VertSizer, 40),
	wxSizer:add(VertSizer, wxStaticText:new(Dialog, ?wxID_ANY, Title), []),
	wxSizer:addSpacer(VertSizer, 5),
  wxSizer:add(VertSizer, wxStaticLine:new(Dialog, [{style, ?wxLI_HORIZONTAL}]), 
              [{flag, ?wxEXPAND}]),
  wxSizer:addSpacer(VertSizer, 20),
  
  Connect = fun(Input) ->
    wxTextCtrl:connect(Input, command_text_updated, []),
    wxTextCtrl:connect(Input, set_focus, [])
  end,
	
  %% Project properties
  FlexGridSizer = wxFlexGridSizer:new(3, [{vgap, 10}, {hgap, 10}]),
  wxSizer:add(FlexGridSizer, wxStaticText:new(Dialog, ?wxID_ANY, "Module:"), []),
  ModuleInput = wxTextCtrl:new(Dialog, ?INPUT_MODULE, [{size, {250,-1}}, 
    {value, State#state.module}]),
  Connect(ModuleInput),
  wxSizer:add(FlexGridSizer, ModuleInput, [{proportion, 1}, {flag, ?wxEXPAND}]),
  Browse = wxButton:new(Dialog, ?wxID_ANY, [{label, "Browse..."}]),
  wxSizer:add(FlexGridSizer, Browse, [{proportion, 0}]),
 
  wxSizer:add(FlexGridSizer, wxStaticText:new(Dialog, ?wxID_ANY, "Main Function:"), []),
  FunctionInput = wxTextCtrl:new(Dialog, ?INPUT_FUNCTION, 
    [{value, State#state.function}]),
  Connect(FunctionInput),
  wxSizer:add(FlexGridSizer, FunctionInput, [{proportion, 1}, {flag, ?wxEXPAND}]),
  wxSizer:add(FlexGridSizer, 0, 0, []),
 
  wxSizer:add(FlexGridSizer, wxStaticText:new(Dialog, ?wxID_ANY, "Arguments:"), []),
  ArgsInput = wxTextCtrl:new(Dialog, ?INPUT_ARGS, 
    [{value, format_args(State#state.args)}]),
  Connect(ArgsInput),
  wxSizer:add(FlexGridSizer, ArgsInput, [{proportion, 1}, {flag, ?wxEXPAND}]),
  wxSizer:add(FlexGridSizer, 0, 0, []),
 
  StaticText = wxStaticText:new(Dialog, ?wxID_ANY, "VM Options:"), %% Disabled. Here for now but likely to be removed
  wxSizer:add(FlexGridSizer, StaticText, []),
  wxStaticText:enable(StaticText, [{enable, false}]),
  TextCtrl = wxTextCtrl:new(Dialog, ?wxID_ANY, []),
  wxTextCtrl:enable(TextCtrl, [{enable, false}]),
  wxSizer:add(FlexGridSizer, TextCtrl, [{proportion, 1}, {flag, ?wxEXPAND}]),
  wxSizer:add(FlexGridSizer, 0, 0, []),
  
  wxFlexGridSizer:addGrowableCol(FlexGridSizer, 1),
  wxSizer:add(VertSizer, FlexGridSizer, [{flag, ?wxEXPAND}, {proportion, 1}]),
  wxSizer:addSpacer(VertSizer, 20),
  
	%% Decscription
	wxSizer:add(VertSizer, wxStaticText:new(Dialog, ?wxID_ANY, "Description"), []),
	wxSizer:addSpacer(VertSizer, 5),  
	Desc = wxPanel:new(Dialog, []),
  DSz = wxBoxSizer:new(?wxHORIZONTAL),
  wxPanel:setSizer(Desc, DSz),
	wxPanel:setBackgroundColour(Desc, ?wxWHITE),
	wxPanel:setForegroundColour(Desc, ?wxBLACK),
	wxSizer:add(VertSizer, Desc, [{proportion, 0}, {flag, ?wxEXPAND}]),
  wxSizer:addSpacer(VertSizer, 40),
  wxSizer:add(VertSizer, wxStaticLine:new(Dialog, [{style, ?wxLI_HORIZONTAL}]), 
              [{flag, ?wxEXPAND}]),
  wxSizer:setItemMinSize(VertSizer, 9, {80,60}),
	wxSizer:addSpacer(VertSizer, 20),
  
  %% Buttons
  ButtonSz = wxBoxSizer:new(?wxHORIZONTAL),
	wxSizer:addStretchSpacer(ButtonSz),
  wxSizer:add(ButtonSz, wxButton:new(Dialog, ?wxID_CANCEL, [{label, "Cancel"}]), [{proportion, 0}]),
	wxSizer:addSpacer(ButtonSz, 10),  
	Open = wxButton:new(Dialog, ?wxID_OK, [{label, "Set"}]),
  wxSizer:add(ButtonSz, Open, [{proportion, 0}]),
  % wxButton:disable(Open), %% Uncomment when input validation is complete
	wxSizer:add(VertSizer, ButtonSz, [{flag, ?wxEXPAND}, {proportion, 0}]),   
	wxSizer:addSpacer(VertSizer, 20),
  
  wxSizer:add(LRSizer, VertSizer, [{proportion, 1}, {flag, ?wxEXPAND}]),
  wxSizer:addSpacer(LRSizer, 20),
	
  wxDialog:fit(Dialog),
  wxDialog:centre(Dialog),
		
  wxDialog:connect(Browse, command_button_clicked, [{skip, true}]),
  
	%% Setup the image list
	ImageList = wxImageList:new(24,24),
	wxImageList:add(ImageList, wxBitmap:new(wxImage:new(deverl_lib_widgets:rc_dir("information.png")))),
	wxImageList:add(ImageList, wxBitmap:new(wxImage:new(deverl_lib_widgets:rc_dir("prohibition.png")))),
  
	NewState = State#state{
		dialog=Dialog, 
		parent=Parent,
    desc=Desc,
    image_list=ImageList
	},
  
	{Dialog, NewState}.
  
    
%% =====================================================================
%% @doc OTP behaviour callbacks
%% @hidden
handle_event(#wx{id=Id, event=#wxFocus{type=set_focus}}, 
             State=#state{desc=Desc, image_list=ImageList}) ->
  HelpStr = case Id of
    ?INPUT_MODULE ->
      "The module that contains the function you want to call.";
    ?INPUT_FUNCTION ->
      "The name of the function to call first.";
    ?INPUT_ARGS ->
      "A comma separated lists of arguements to pass to the function."
  end,
  insert_desc(Desc, HelpStr, [{bitmap, wxImageList:getBitmap(ImageList, ?ID_BITMAP_INFO)}]),  
  {noreply, State};
handle_event(#wx{id=?INPUT_MODULE, event=#wxCommand{type=command_text_updated, cmdString=Input}}, 
             State) ->
  {noreply, State#state{module=Input}};
handle_event(#wx{id=?INPUT_FUNCTION, event=#wxCommand{type=command_text_updated, cmdString=Input}}, 
             State) ->
  {noreply, State#state{function=Input}};  
handle_event(#wx{id=?INPUT_ARGS, event=#wxCommand{type=command_text_updated, cmdString=Input}}, 
             State) ->
  {noreply, State#state{args=Input}}.
handle_info(Msg, State) ->
  io:format( "Got Info ~p~nMsg:~p",[State, Msg]),
  {noreply,State}.
%% @hidden
handle_call(shutdown, _From, State) ->
  {stop, normal, ok, State};
handle_call(build_config, _From, State=#state{module=Module, function=Function, args=Args}) ->
  Config = [{module, Module}, {function, Function}],
  Result = case Args of
    [] -> 
      Config;
    Args -> 
      Config ++ [{args, Args}]
  end,
  {reply, Result, State}.
%% @hidden  
handle_cast(_, State) ->
  {noreply,State}.
%% @hidden
code_change(_, _, State) ->
  {stop, ignore, State}.
%% @hidden
terminate(_Reason, #state{dialog=Dialog}) ->
	wxDialog:destroy(Dialog).
	

%% =====================================================================
%% Internal functions
%% =====================================================================

%% =====================================================================
%% @doc PASTED FROM ANOTHER DIALOG - THIS IS COMMON CODE - MOVE IT!
	
insert_desc(Description, Msg) ->
	insert_desc(Description, Msg, []).

insert_desc(Description, Msg, Options) ->
	SzFlags = wxSizerFlags:new([{proportion, 0}]),
	wxSizerFlags:expand(wxSizerFlags:border(SzFlags, ?wxTOP, 10)),
  Sz = wxWindow:getSizer(Description),
  wxSizer:clear(Sz, [{delete_windows, true}]),
	wxSizer:addSpacer(Sz, 10),
	case proplists:get_value(bitmap, Options) of
		undefined -> ok;
		Bitmap -> 
			wxSizer:add(Sz, wxStaticBitmap:new(Description, ?wxID_ANY, Bitmap), [{border, 5}, {flag, ?wxTOP bor ?wxRIGHT}])
	end,
	wxSizer:add(Sz, wxStaticText:new(Description, ?wxID_ANY, Msg), SzFlags),
	wxPanel:layout(Description).


format_args([]) -> [];
format_args(Args) ->
  format_args(Args, []).

format_args([], Acc) -> 
  Acc;
format_args([H | T], Acc) ->
  format_args(T, [io_lib:format("~s ", [H]) | Acc]).

%% =====================================================================
%% @doc
%% @hidden
show(This) -> wxDialog:show(This).
%% @hidden
showModal(This) -> wxDialog:showModal(This).