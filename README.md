Aliases brought to the ultimate level.

# Installation

## zgen

```
zgen load seletskiy/zsh-hijack
```

# Usage

## In .zshrc

```zsh
hijack:transform 'sed -re "s/^(ri|ya|fo)((no|pa|re|ci|vo|mu|xa|ze|bi|so)+)(\s|$)/ssh \1\2.in.example.com/"'
```

Will provide following command transformation:

```
$ yano
    -> ssh yano.in.example.com

$ yapapa
    -> ssh yapapa.in.example.com
```

# Tips and tricks

## Do not show transformed line in the 'up-history' widget:

```zshrc
bindkey -v "^P" hijack:history-substring-search-up
bindkey -v "^[OA" hijack:history-substring-search-up
```
