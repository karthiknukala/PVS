![PVS Logo](pvslogo.gif)

# PVS Specification and Verification System

PVS is a verification system: that is, a specification language integrated with support tools and a theorem prover. It is intended to capture the state-of-the-art in mechanized formal methods and to be sufficiently rugged that it can be used for significant applications. PVS is a research prototype: it evolves and improves as we develop or apply new capabilities, and as the stress of real use exposes new requirements.

For documentation, please visit http://pvs.csl.sri.com/.

## Installation

### Prebuilt packages

PVS (as of version 8.1) is continuously built in GitHub runners for the following architectures:
 - MacOS Apple Silicon (aarch64/arm64)
 - MacOS x86/64
 - Linux (Ubuntu) (aarch64/arm64)
 - Linux (Ubuntu) (x86/64)

Please see https://github.com/SRI-CSL/PVS/releases for the appropriate version.

VSCode extensions will automatically pull the right version from here, and a similar Emacs integration is on the way.

### Building from source

PVS is a heavily Emacs-oriented system, with server-mode/headless deployments for VSCode/CLI developments. If you wish to use Emacs or VSCode, please have that installed. 

To build PVS from source, please have installed the appropriate developer utilities (XCode CLI tools on MacOS, build-essential on Ubuntu, etc.).

Please have SBCL installed - see https://www.sbcl.org/getting.html for more information on that.

Then, clone the repository and enter it:

```
git clone https://github.com/SRI-CSL/PVS.git PVS

cd PVS
```

Run `./configure` to generate the Makefile and run `make`.

PVS should be installed in your cloned directory as `pvs` and can now be launched.

```
% ./pvs --help
usage:
       pvs [-options ...] [file]
where options include:
  -h | -help | --help  print out this message
  -version | --version show the PVS version number
  -emacs emacsref    emacs, xemacs, or pathname
  -load-after efile  loads emacs file after PVS emacs files
  -lisp name         lisp name (allegro or sbclisp)
  -image name        see make-new-pvs-image in src/utils.lisp
  -runtime           use the runtime image
  -patchlevel level  patchlevel (none, rel, test, exp or 0-3, resp.)
  -batch             run in batch mode
  -timeout number    use a timeout for commands or proofs in batch mode
  -nobg              don't put PVS in the background
  -port number       run PVS as XML-RPC server on port number
  -raw               run PVS without Emacs
  -v number          verbosity level for batch mode (0-3)
  -q           do not load ~/.emacs, ~/.pvsemacs, or ~/.pvs.lisp files
  -e expr      evaluate the Emacs expression
  -l efile     load the given Emacs file (before PVS emacs files)
  -E expr      evaluate the Lisp expression
  -L lfile     load the given Lisp file (after PVS initializes)
  and any Emacs or X window options
To change the title and icon names, use -title and -xrm, for example,
  pvs -title foo -xrm "pvs*iconName:bar"
```


## NASALib PVS Libraries

Please see https://github.com/nasa/pvslib for information on acquiring the NASALib developments.


Source layout
-------------
Files:

* README           - this file
* pvs              - the shell script for invoking pvs
* pvsio-web        - the shell script for invoking the pvsio-web prototyping tool
* pvs.sty	   - the style file supporting LaTeX output
* pvs-tex.sub      - the default substitution file for generating LaTeX

Directories:
* Examples - some simple example specifications
* emacs    - Emacs files.
* wish     - Tcl/Tk files
* bin      - shell scripts and executables
* lib      - prelude, help files, and libraries
* pvsio-web  - PVSio-web prototyping tool and example prototypes
* javascript -  experimental javascript front-ends for PVS. See [javascript/README.md](javascript/README.md) for more info on how to run the tools.
