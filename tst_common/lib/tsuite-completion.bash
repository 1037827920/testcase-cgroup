# bash/zsh completion support for tsuite.

# To use these routines:
#
#    1) Copy this file to somewhere (e.g. ~/.tsuite-completion.bash).
#    2) Add the following line to your .bashrc/.zshrc:
#        source ~/.tsuite-completion.bash

_tsuite_completion() {
  local cur prev

  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD - 1]}

  case ${COMP_CWORD} in
  1)
    COMPREPLY=($(compgen -W "help new list compile setup run teardown clean cleanall" -- ${cur}))
    ;;
  2)
    case ${prev} in
    new)
      COMPREPLY=($(compgen -W "case" -- ${cur}))
      ;;
    run)
      local arr i file
      arr=($(grep --include \*.c --include \*.sh --include \*.py -Ril "@用例名称:" testcase/))
      COMPREPLY=()
      for ((i = 0; i < ${#arr[@]}; ++i)); do
        file=${arr[i]}
        if [[ -d $MEMO_DIR/$file ]]; then
          file=$file/
        fi
        COMPREPLY[i]=$file
      done
      ;;
    esac
    ;;
  3)
    case ${prev} in
    case)
      COMPREPLY=($(compgen -W "sh c py" -- ${cur}))
      ;;
    esac
    ;;
  *)
    COMPREPLY=()
    ;;
  esac
}

complete -F _tsuite_completion tsuite
