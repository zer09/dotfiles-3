#!/bin/bash
############################
# ./install.sh
# This script creates symlinks from the home directory to any desired dotfiles
# in ~/dotfiles
# Install brew (OSX only), git, zsh (can be skipped with -z), oh-my-zsh, vim
############################
# TODO LIST
# - add options: prefix, no-root
#
############################

########## Variables

dir=~/dotfiles               # dotfiles directory
olddir=~/old_dotfiles        # old dotfiles backup directory
files="bashrc vimrc vim zshrc gitconfig oh-my-zsh tmux.conf editorconfig"    # list of files/folders to symlink in homedir

source ${dir}/task-logger.sh || exit 1

# Get OS. Installing in windows is the same as in Linux
# because I use Cygwin
OSX=""
INSTALL="sudo apt-get install -y"
if [[ "$(uname)" = "Darwin" ]]; then
  OSX="YES"
  INSTALL="brew install"
fi

fail() {
  ko
  bad "$@"
}

crash() {
  ko
  bad "$@"
  exit 1
}

####### Verifications and backup #######

# Verification of the install dir
check_install_dir() {
  working -n "Checking dotfiles dir"
  log_cmd -c install-dir test "$(cd "$(dirname "$0")" && pwd)" = "$dir" || crash  "The dotfiles path is wrong! It should be ${dir}"
  cd $dir || crash "Cannot access $dir"
}

# create old_dotfiles in homedir
_backup_dir() {
  mkdir -p $olddir || return 1
  for file in $files; do
    if [ -f ~/."$file" -o -d ~/."$file" ]; then
      mv -f ~/."$file" "$olddir" || return 1
    fi
  done
}
backup_dir() {
  local i tmp
  i=0
  tmp="$olddir"
  while [[ -d "$olddir" ]]; do
    ((i++))
    olddir="${tmp}-$i"
  done
  working -n "Backing up files to $olddir"
  log_cmd $0 _backup_dir || crash "Backup failed, aborting"
}

_symlinks() {
  for file in $files; do
    ln -s "${dir}/${file}" ~/."$file" || return 1
  done
}

####### Functions #######

# Install Homebrew only for OSX
install_brew() {
  if [[ "$OSX" ]]; then
    if [[ ! -x $(which brew) ]]; then
      working -n "Installing Homebrew(brew)"
      log_cmd -c brew ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi
  fi
}

install_git() {
  if [[ ! -x $(which git) ]]; then
    working -n "Installing Git"
    log_cmd $0 ${INSTALL} git || ko
  fi
}

# Install zsh, need git and brew
_add_zsh() {
  sudo echo $(which zsh) > /etc/shells
}
_install_zsh() {
  if [[ ! -x $(which zsh) ]]; then
    working -n "Installing zsh"
    log_cmd zsh-install ${INSTALL} zsh || return 1
  fi
  if [[ ! -d ${dir}/oh-my-zsh/ ]]; then
    working -n "Cloning oh-my-zsh"
    log_cmd oh-my-zsh git clone https://github.com/robbyrussell/oh-my-zsh.git || return 1
  fi
  if [[ ! "$SHELL" == $(which zsh) ]]; then
    if [[ ! "$(grep "$(which zsh)" /etc/shells)" ]]; then
      working -n "Adding zsh to /etc/shells"
      log_cmd add-zsh _add_zsh || return 1
    fi
    important 'You should manually change your shell with chsh $(which zsh)'
    #if [[ $(uname) == 'Linux' || $(uname) == 'Darwin' ]]; then
      #working -n "Changing the default shell for $USER"
      #log_cmd change-shell chsh -s "$(which zsh)" || return 1
    #fi
  fi
  # Install posva zsh theme
  zsh_theme="oh-my-zsh/themes/posva.zsh-theme"
  if [ ! -f "$zsh_theme" ]; then
    working -n "Installing zsh theme"
    log_cmd zsh-theme ln -s "${dir}/posva.zsh-theme" "$zsh_theme" || return 1
  fi
  zsh_theme="oh-my-zsh/themes/posva-powerline.zsh-theme"
  if [ ! -f "$zsh_theme" ]; then
    working -n "Installing powerline zsh theme"
    log_cmd zsh-theme-powerline ln -s "${dir}/posva-powerline.zsh-theme" "$zsh_theme" || return 1
  fi
}
install_zsh() {
  _install_zsh || ko
}

_install_vim() {
  if [[ ! -x $(which vim) ]]; then
    if [[ "$OSX" ]]; then
      working -n "Installing vim"
      log_cmd vim-install brew install vim --with-lua --with-python3 || return 1
    else
      if [[ ! -x $(which hg) ]]; then
        working -n "Installing hg(Mercurial)"
        log_cmd hg-install ${INSTALL} mercurial || return 1
      fi
      if [[ ! -d "vim_src" ]]; then
        working -n "Cloning vim repo"
        log_cmd vim-clone hg clone https://vim.googlecode.com/hg/ vim_src || return 1
      fi
      cd vim_src || return 1
      working -n "Installing ncurses"
      log_cmd ncurses-install ${INSTALL} libncurses5-dev || return 1
      working -n "Vim ./configure.sh"
      log_cmd vim-conf ./configure --prefix=/usr/local/ --enable-rubyinterp --enable-pythoninterp --enable-luainterp --with-features=huge || return 1
      working -n "Vim make -j 4"
      log_cmd vim-make make -j 4 || return 1
      working -n "Vim make install"
      log_cmd sudo make install || return 1
    fi
  fi
  # backup dir. My vimrc does this already
  #working -n "Creating vim backup directory"
  #log_cmd vim-back mkdir -p vim/backup || return 1

  # Plugins
  if [[ ! -d ${dir}/vim/bundle/Vundle.vim ]]; then
    working -n "Installing Vundle"
    log_cmd vundle git clone https://github.com/gmarik/Vundle.vim.git vim/bundle/Vundle.vim || return 1
  fi

  # install plugins
  working -n "Installing vim plugins"
  reset_timer 5
  if vim -Nu "$dir/vim-plugins.vim" +PluginInstall! +qall; then
    echo -n "[$(get_timer 5) s]"
    ok
  else
    echo -n "[$(get_timer 5) s]"
    return 1
  fi
}

install_vim() {
  _install_vim || ko
}

install_YCM() {
  if [[ -d "${dir}/vim/bundle/YouCompleteMe" ]]; then
    working -n "Compiling YouCompleteMe"
    cd "${dir}/vim/bundle/YouCompleteMe"
    log_cmd ycm ./install.sh --clang-completer || fail "Could not install YouCompleteMe. Check at $LOG_DIR/ycm.err for details"
    cd "$dir"
  fi
}

install_font() {
  if [[ "$OSX" ]]; then
    cp "$1" ~/Library/Fonts/ || return 1
  else
    mkdir -p ~/.fonts
    cp "$1" ~/.fonts/ || return 1
  fi
  return 0
}

_install_powerfonts() {
  for f in $dir/powerline-fonts/*; do
    install_font "$f" || return 1
  done
}

check_installed_fonts() {
  # return as soon as we find a font that doesn't exist
  for f in $dir/powerline-fonts/*; do
    f=$(basename "$f")
    if [[ "$OSX" ]]; then
      [[ -f "~/Library/Fonts/$f" ]] || return 0
    else
      warning checking $f
      [[ -f "~/.fonts/$f" ]] || return 0
    fi
  done
  return 1
}

install_powerfonts() {
  if check_installed_fonts; then
    working -n "Copying powerline-fonts"
    log_cmd font-copy _install_powerfonts || fail "Could not copy the fonts. Check logs at $LOG_DIR"
    if [[ -z "$OSX" ]]; then
      working -n "Updating font cache"
      log_cmd font-cache fc-cache -fv || ko
    fi
    info "Remeber to change the font to Liberation Mono for Powerline"
  fi
}

install_powerline() {
  if [[ ! -d ${dir}/powerline/ ]]; then
    working -n "Cloning powerline"
    log_cmd powerline-git git clone https://github.com/Lokaltog/powerline.git ${dir}/powerline || ko
  fi
  if [[ -x $(which pip) ]]; then
    if [[ ! -x $(which powerline) ]]; then
      working -n "Installing powerline-status"
      log_cmd powerline-status sudo pip install powerline-status || ko
    fi
  else
    warning "powerline-status not installed because pip is missing"
  fi
}

install_python() {
  local cmd
  if [[ "$OSX" ]]; then
    working -n "Installing Python"
    log_cmd python "$INSTALL" python || ko
  else
    if ! dpkg -s python-dev >/dev/null 2>/dev/null; then
      working -n "Installing Python"
      log_cmd python "$INSTALL" python-dev || ko
    fi
  fi
}

install_pip() {
  # brew installs pip by default
  if [[ ! "$OSX" ]]; then
    if ! dpkg -s python-pip >/dev/null 2>/dev/null; then
      working -n "Installing pip"
      log_cmd pip $INSTALL python-pip || ko
    fi
  fi
}

install_zsh_syntax_highlight() {
  if [[ ! -d ${dir}/zsh-syntax-highlighting/ ]]; then
    working -n "Cloning zsh-syntax-highlighting"
    log_cmd zsh-syntax git clone git://github.com/zsh-users/zsh-syntax-highlighting.git || ko
  fi
}

##### Call everything #####

important "Logs are at $LOG_DIR"

check_install_dir

backup_dir

working -n "Symlinking dotfiles"
log_cmd symlink _symlinks || fail "Symlink failed. Check logs at $LOG_DIR"

install_brew

install_git

if [ ! "$1" = -z ]; then
  install_zsh
fi

install_python

install_vim

install_pip

install_powerline
install_powerfonts

install_zsh_syntax_highlight

finish
