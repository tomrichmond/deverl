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
%% @doc This module is builds and provides functions for updating the
%% status bar. It is implemented as a wxPanel to provide more
%% flexibility than is currently offered by the built in wxStatusBar.
%% @end
%% =====================================================================

-module(deverl_sb_wx).

-include_lib("wx/include/wx.hrl").
-include("deverl.hrl").

%% wx_object
-behaviour(wx_object).

-export([init/1, terminate/2,  code_change/3,
         handle_info/2, handle_cast/2, handle_call/3, handle_event/2]).

%% Client API
-export([
	start/1,
	set_text/2
	]).

%% Macros
-define(FG_COLOUR, {60,60,60}).
-define(FONT_SIZE, 11).
-define(PADDING, 4).
-define(TIMEOUT, 1000).

%% Server state
-record(state, {parent :: wxWindow:wxWindow(),
                sb :: wxWindow:wxWindow(),     %% Status bar
                fields :: [wxStaticText:wxStaticText()]
                }).


%% =====================================================================
%% Client API
%% =====================================================================

%% =====================================================================
%% @doc

-spec start(Config) -> wxWindow:wxWindow() when
  Config :: list().

start(Config) ->
	wx_object:start({local, ?MODULE}, ?MODULE, Config, [{debug, [log]}]).


%% =====================================================================
%% @doc Set the text in the specified field.

-spec deverl_sb_wx:set_text(Field, Label) -> Result when
      Field :: {field, atom()},
      Label :: unicode:chardata(),
      Result :: atom().

set_text({field, Field}, Label) ->
	wx_object:cast(?MODULE, {settext, {Field, Label}}).


%% =====================================================================
%% Callback functions
%% =====================================================================
%% @hidden
init(Config) ->
	Parent = proplists:get_value(parent, Config),

	Sb = wxPanel:new(Parent, []),
	SbSizer = wxBoxSizer:new(?wxHORIZONTAL),
	wxPanel:setSizer(Sb, SbSizer),
	Separator = wxBitmap:new(wxImage:new(deverl_lib_widgets:rc_dir("separator.png"))),

	add_label(Sb, ?wxID_ANY, SbSizer, "Text:"),
	Line = wxStaticText:new(Sb, ?SB_ID_LINE, "1", []),
	set_style(Line),
	wxSizer:add(SbSizer, Line, [{border, ?PADDING}, {flag, ?wxALL}]),

	add_separator(Sb, SbSizer, Separator),

	add_label(Sb, ?wxID_ANY, SbSizer, "Selection:"),
	Selection = wxStaticText:new(Sb, ?SB_ID_SELECTION, "-", []),
	set_style(Selection),
	wxSizer:add(SbSizer, Selection, [{border, ?PADDING}, {flag, ?wxALL}]),

	add_separator(Sb, SbSizer, Separator),

	Help = wxStaticText:new(Sb, ?SB_ID_HELP, "", []),
	set_style(Help),
	wxSizer:add(SbSizer, Help, [{proportion, 1}, {border, ?PADDING}, {flag, ?wxEXPAND bor ?wxALL bor ?wxALIGN_RIGHT}]),

	wxSizer:layout(SbSizer),
	Fields = [{line, Line}, {selection, Selection}, {help, Help}],
	{Sb, #state{parent=Parent, sb=Sb, fields=Fields}}.
%% @hidden
handle_info(Msg, State) ->
	io:format("Got Info ~p~n",[Msg]),
	{noreply,State}.
%% @hidden
handle_cast({settext, {Field,Label}}, State=#state{fields=Fields, sb=Sb}) ->
	T = proplists:get_value(Field, Fields),
	set_label(T, Label),
	wxSizer:layout(wxPanel:getSizer(Sb)),
  {noreply,State}.
%% @hidden
handle_call(fields, _From, State) ->
  {reply, State#state.fields, State};
handle_call(shutdown, _From, State) ->
  ok,
  {reply,{error, nyi}, State}.
%% @hidden
handle_event(_Event, State) ->
	{noreply, State}.
%% @hidden
code_change(_, _, State) ->
  {ok, State}.
%% @hidden
terminate(_Reason, #state{sb=Sb}) ->
	wxPanel:destroy(Sb).


%% =====================================================================
%% Internal functions
%% =====================================================================

%% =====================================================================
%% @doc Set common status bar styles i.e font
%% @private

-spec set_style(wxWindow:wxWindow()) -> boolean().

set_style(Window) ->
	Font = wxFont:new(?FONT_SIZE, ?wxFONTFAMILY_SWISS, ?wxNORMAL, ?wxNORMAL,[]),
	wxWindow:setFont(Window, Font),
	wxWindow:setForegroundColour(Window, ?FG_COLOUR).


%% =====================================================================
%% @doc Insert a separator into the status bar
%% @private

-spec add_separator(wxPanel:wxPanel(), wxSizer:wxSizer(), wxBitmap:wxBitmap()) -> wxSizerItem:wxSizerItem().

add_separator(Sb, Sizer, Bitmap) ->
	wxSizer:add(Sizer, wxStaticBitmap:new(Sb, 345, Bitmap), [{flag, ?wxALIGN_CENTER_VERTICAL}]).


%% =====================================================================
%% @doc Insert a text label into the status bar
%% @private

-spec add_label(wxPanel:wxPanel(), integer(), wxSizer:wxSizer(), string()) -> wxSizerItem:wxSizerItem().

add_label(Sb, Id, Sizer, Label) ->
	L = wxStaticText:new(Sb, Id, Label),
	set_style(L),
	wxSizer:add(Sizer, L, [{border, ?PADDING}, {flag, ?wxALL}]).


%% =====================================================================
%% @doc Set the text
%% @private

-spec set_label({field, Field}, string()) -> ok when
  Field :: line | selection | help.

set_label(Field, Label) ->
	wxStaticText:setLabel(Field, Label).
