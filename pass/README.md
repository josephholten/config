# pass

interacts  with already present gpg agent

## setup

- `yay -S pass; yay -S pass-git-helper`
- first time: `pass init joseph@holten.com`,
  - otherwise `ln -s $HOME/config/pass/password-store $HOME/.password-store`

## pass usage

- `pass insert NAME`
- retrieve by `pass NAME`

## pass-git-helper

- `ln -s $HOME/config/pass/pass-git-helper $HOME/.config/pass-git-helper`
- `git config --global credential.helper $(which pass-git-helper)`
