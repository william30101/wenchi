android.vim
==============

Android.vim is a VIM plugin designed to streamline android development without
the need of a complete IDE. Android.vim provides convenient commands for
common tasks such as building your apps, deploying to devices, and simplifying
code navigation.

Under Construction
------------------

Android.vim is still in its infancy. That being said there is not much in the
way of helpful error messages. Here are some gotchas to watch out for:

- Android.vim expects that your current working directory is the root of an
  android project. If this is not the case many of the commands will not be
  available.

- You must have the android platform-tools installed and added to your PATH
  variable. Specifically adb, ant, and the android executable. Many of
  android.vim's commands simply wrap the interface to these binaries.
  Eventually I plan to have a variable that a user can set to specify the
  location of these binaries should they not exist in the PATH, but the
  binaries themselves will always be required.

- I have only tested this program on x64 linux. I imagine that the plugin
  should work fine on mac and linux, but there may be problems when attempting
  to integrate with windows. I am not against fixing windows issues, but I
  would like to know someone cares before I put forth the effort :).

If you do encounter any problems please open an issue report, and/or if you are
feeling really enthusiastic a pull request :). Thanks!

Installation
------------

The easiest installation method is using Tim Pope's excellent
[pathogen.vim](https://github.com/tpope/vim-pathogen), simply copy
and paste the following into your terminal:

    cd ~/.vim/bundle
    git clone git://github.com/mgarriott/vim-android.git

Once you have generated the help tags you can view the documentation with
`:help android`.

If you are not using [pathogen.vim](https://github.com/tpope/vim-pathogen)
you can install the plugin by copying the files manually into the respective
sub-directories of your ~/.vim directory.

Contributing
------------

If you are interesting in contributing to android.vim please ensure your
commits follow a few simple guidelines.

- Avoid trailing whitespace.
- Format commit messages in the imperative present tense.

License
-------

BSD 2-Clause (see LICENSE file).
