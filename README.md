# vim-foldpeek

vim-foldpeek starts from a partial fork of
[LeafCage/foldCC.vim](https://github.com/LeafCage/foldCC.vim).
Thanks!

## Installation

Install the plugin using your favorite package manager.

### For dein.vim

```vim
call dein#add('kaile256/vim-foldpeek')
```

## Features

- You can peek another line, skipping lines which have few information.

  > Set skip-pattern in g:foldpeek#skip_patterns or b:foldpeek_skip_patterns.  
  > The default is `'^[\-=/{!* ]*$'`.

- As default, you will get the number of folded lines at tail.

  > Addition to that, when each of numbers are 2 or more,
  > you can get the number of `foldlevel` at head
  > and the `number` of peeked line as the top of folded lines is 1.

| with foldpeek#text() (in vim-foldpeek)                                                                              |
| ------------------------------------------------------------------------------------------------------------------- |
| ![tarai_peek](https://user-images.githubusercontent.com/46470475/71542810-3b0d5800-29ae-11ea-88aa-05d7246935c9.png) |

| with foldtext() (default)                                                                                           |
| ------------------------------------------------------------------------------------------------------------------- |
| ![tarai_text](https://user-images.githubusercontent.com/46470475/71542809-3b0d5800-29ae-11ea-9d34-297d9ab86514.png) |

For more detail, type `:h foldpeek` in vim's command line and see
[doc/foldpeek.txt](https://github.com/kaile256/vim-foldpeek/blob/master/doc/foldpeek.txt).

## License

MIT
