Deverl
======

An Erlang IDE dedicated to learning erlang, written in Erlang.

Released under the GNU general public license version 3.

### Requirements

Deverl requires a working installation of Erlang OTP which includes the wx application.
For detailed installation instructions for all platforms read [INSTALL](https://raw.github.com/deverl-ide/deverl/master/INSTALL.md).

### Starting Deverl

1. Install Erlang OTP and wxWidgets as described in Requirements.
2. Clone this repository:
         
        git clone https://github.com/deverl-ide/deverl.git
3. Change directory:

        cd deverl/deverl
4. Compile:

        erl -make
5. Start Deverl, at the unix command prompt type:

        erl -pa ebin -s deverl start
 or, from the Erlang shell in the root diectory of Deverl:

        deverl:start().


### Folders

	/deverl   - The main project directory for source code and distribution.
	/misc     - Other files not related to the distribution.


### Bug/Issues

To view/report issues ~~visit our [trac page](http://www.tgrsvr.co.uk/trac "trac")~~ please use our GitHub issue tracker.

<div align="center">
	<img src="https://raw.github.com/deverl-ide/deverl/master/misc/linux_screenshot.png" alt="Erlang IDE" />
</div>
