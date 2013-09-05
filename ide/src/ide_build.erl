-module(ide_build).

-export([
	compile/0
]).


compile() ->
  case doc_manager:get_selected_editor() of
    {error, _} ->
      ok;
    {ok, {Index, Pid}} ->
      doc_manager:save_file(Index, Pid),
      Path = filename:rootname(editor:get_editor_path(Pid)),
      compile_file(Path)
  end.
  

compile_file(Path) ->
<<<<<<< HEAD
	port:call_port("c(" ++ Path ++ ")." ++ io_lib:nl()).
	
=======
	io:format("Path: ~p~n", [Path]),
	port:call_port("c(\"" ++ Path ++ "\")." ++ io_lib:nl()).
>>>>>>> e9781b8d4ce0534ad069773f0bc3a17adef77311
