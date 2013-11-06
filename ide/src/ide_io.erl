%% =====================================================================
%% @author
%% @copyright
%% @title ide_io.erl
%% @version
%% @doc This module manages file i/o.
%% @end
%% =====================================================================

-module(ide_io).

-include_lib("wx/include/wx.hrl").

%% Client API
-export([
        create_directory_structure/3,
        create_new_file/1,
        open_new/1,
        read_file/1,
        save_as/2,
        save/2
        ]).


%% =====================================================================
%% Client API
%% =====================================================================

%% =====================================================================
%% @doc Create the directory structure for a new project.

create_directory_structure(_Parent, Name, Path) ->
	Root = filename:join([Path, Name]),
  try
    create_dir(Root),
    create_dir(filename:join([Root, "ebin"])),
    create_dir(filename:join([Root, "priv"])),
    create_dir(filename:join([Root, "include"])),
    create_dir(filename:join([Root, "src"])),
		copy_emakefile(Root),
		Root
  catch
    throw:E -> throw(E)
  end.
  
  
%% =====================================================================
%% @doc Create a new file on disc.

create_new_file(Path) ->
  case file:open(Path, [write, read]) of
    {error, _Reason} ->
      error;
    File ->
      file:close(File),
      ok
  end.


%% =====================================================================
%% @doc Read a file from the path specified by the user.

-spec open_new(Parent) -> Result when
  Parent :: wxWindow:wxWindow(),
  Result :: {string(), string(), string()}
          | {'cancel'}.

open_new(Parent) ->
	Dialog = wxFileDialog:new(Parent, [{style, ?wxFD_OPEN}]),
	case wxFileDialog:showModal(Dialog) of
		?wxID_OK ->
			Path = wxFileDialog:getPath(Dialog),
			Filename = wxFileDialog:getFilename(Dialog),
			{Path, Filename, read_file(Path)};
		?wxID_CANCEL ->
			{cancel}
	end.


%% =====================================================================
%% @doc Read the file at Path.

read_file(Path) ->
	try
		{ok, Contents} = file:read_file(Path),
		binary_to_list(Contents)
	catch
		error:_E ->
			throw("Could not read file.")
	end.


%% =====================================================================
%% @doc Write the data to the path specified by the user through a
%% dialog.
%% A new file will be created if the specified path doesn't exist, and
%% an existing file will be overwritten.

-spec save_as(Parent, Contents) -> Result when
    Parent :: wxWindow:wxWindow(),
    Contents :: string(),
    Result :: {'ok', {string(), string()}}
            | {'cancel'}.

save_as(Parent, Contents) ->
	Dialog = wxFileDialog:new(Parent, [{style, ?wxFD_SAVE bor
											   ?wxFD_OVERWRITE_PROMPT bor
											   ?wxFD_CHANGE_DIR}]),
	case wxFileDialog:showModal(Dialog) of
		?wxID_OK ->
			Path = wxFileDialog:getPath(Dialog),
			save(Path, Contents),
			{ok, {Path, wxFileDialog:getFilename(Dialog)}};
		?wxID_CANCEL ->
			{cancel}
	end.


%% =====================================================================
%% @doc Write the data to disk.

-spec save(Path, Contents) -> 'ok' when
	Path :: string(),
	Contents :: string().

save(Path, Contents) ->
	try
    Result =  file:open(Path, [write]),
		{ok, Fd} = file:open(Path, [write]),
		ok = file:write(Fd, Contents),
		ok = file:close(Fd)
	catch
		error:{badmatch,{error,Error}} -> 
      get_error_message(Error, Path)
	end.


%% =====================================================================
%% Internal functions
%% =====================================================================

%% =====================================================================
%% @doc Create directory Dir.

create_dir(Dir) ->
	case file:make_dir(Dir) of
    {error, Error} ->
      get_error_message(Error, Dir);
    ok -> ok
	end.


%% =====================================================================
%% @doc Get a more comprehensive error message.
 
get_error_message(Error, Path) ->
  Filename = filename:basename(Path),
  case Error of
    eacces ->
			throw("Cannot access " ++ Filename ++ ", check your permissions.");
		eexist ->
			throw(Filename ++ " already exists.");
		enoent ->
			throw("The path " ++ Path ++ " is invalid.");
		enospc ->
			throw("There is a no space left on the device.");
		_ ->
  		throw("An error occurred.")
  end.


%% =====================================================================
%% @doc

copy_file(Source, Dest) ->
	case file:copy(Source, Dest) of
		{ok, _BytesCopied} -> ok;
		{error, Reason} -> throw("Copy failed: " ++ atom_to_list(Reason))
	end.


%% =====================================================================
%% @doc

copy_emakefile(Root) ->
	case filelib:is_file("../priv/templates/emakefile.txt") of
		true ->
			copy_file("../priv/templates/emakefile.txt", filename:join([Root, "Emakefile"]));
		false -> throw("Emakefile template not found.")
	end.	