#!/bin/bash

## Replace with your private key ID
private_key=6D59FA6B

## Replace with the recipient's public key ID
public_key=15403B20

## Functions
usage()  { 
	echo "Usage: $0 [-w <WEEK>] [-g] [-v] [-h]" 1>&2; 
	exit 1; 
}
nolink() { echo "No LINK $1"            1>&2; exit 1; }

## Assignments Results folder
RESDIR="$HOME/RESULT/"

## SHASUM Filename
SHA="SHA256SUM"

## Logfile (TODO)
LOG=""

## WEEKURL
WEEKURL="https://os.vlsm.org/WEEK/WEEK.txt"

## Check Week
unset WEEK DEFAULT GIT VERBOSE
GIT=0
VERBOSE=0 
if [ ! -z "${1##*[!0-9]*}" ] ; then
  WEEK=$1
elif [ -z $1 ] ; then
  DEFAULT=1
else while getopts ":w:W:g:v:gv:h" varTMP
  do
    case "${varTMP}" in 
	w|W)
       	  WEEK=${OPTARG} 
          if [ ! -z "${WEEK##*[!0-9]*}" ]; then 
	    echo "-w requires input dd./n"
	    usage 
	  fi
	  ;;
    	g)
	  GIT=1 
	  ;;
	v)
	  VERBOSE=1 
	  ;;
	## TODO: Full auto (-a)
	## TODO: Auto log
	## TODO: changeFilenames etc.
	h)
	  usage
	  ;;
	\?)
	  echo "Invalid option: -$varTMP" >&2
	  ;;
	esac
  done
  [ -z $WEEK ] && usage
fi

if [ $DEFAULT ] ; then 
  if [ $verbose -eq 1 ]; then
    echo "Checking Week"
    echo "Asking $WEEKURL"
  fi
  
  [[ $(wget $WEEKURL -O- 2>/dev/null) ]] || nolink $WEEKURL
  intARR=($(wget -q -O - $WEEKURL | awk '/\| Week / { 
    cmd = "date -d " $2 " +%s"
    cmd | getline mydate
    close(cmd)
    print mydate + (86400 * 6)
  }'))
  DATE=$( LANG=en_us_8859_1;date -d $(date +%d-%b-%Y) +%s)
  for II in ${!intARR[@]} ; do
    (( $DATE > ${intARR[$II]} )) || break;
  done
  WEEK=$II
fi

(( WEEK > 11 )) && WEEK=11
WEEKS=$(printf "W%2.2d\n" $WEEK)

## Is this the correct WEEK?
read -r -p "Is this WEEK $WEEKS? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        ;;
    *)
        echo "It is not Week $WEEKS!"
        echo "myscript.sh 00(week)"
        exit 1
        ;;
esac

## Checking Myupdate
if [ $(head -n 1 $HOME/git/os231/TXT/myupdate.txt | tail -c 4) != "$WEEKS" ]; then
  echo "myupdate.txt is of a different week!"
  cat $HOME/git/os231/TXT/myupdate.txt
  read -p "Are you sure you want to continue? (y/n)" ans
  if ! [[ $ans =~ y ]]; then
    echo "script canceled"
    exit 0
  fi
elif [ $VERBOSE -eq 1 ]; then
  echo "myupdate.txt is of same week, continuing..."
fi

## Collecting Assignemts
pushd $RESDIR
for II in W?? ; do
    [ -d $II ] || continue
    TARFILE=my$II.tar.bz2
    TARFASC=$TARFILE.asc
    rm -vf $TARFILE $TARFASC
    
    echo "tar cfj $TARFILE $II/"
    tar cfj $TARFILE $II/
    
    if [ $VERBOSE -eq 1 ]; then
        echo "Encrypt $II"
    fi
    echo "gpg --armor --output $TARFASC --encrypt --recipient $public_key --recipient $private_key $TARFILE" 
    gpg --armor --output $TARFASC --encrypt --recipient $public_key --recipient $private_key $TARFILE
done
popd

## Move this week's assignment
if [[ "$WEEKS" != "W00" ]] && [[ "$WEEKS" != "W01" ]] ; then
    II="${RESDIR}my$WEEKS.tar.bz2.asc"
    echo "Check and move $II..."
    [ -f $II ] && mv -vf $II .
fi

## Cleaning
echo "rm -f $SHA $SHA.asc"
rm -f SHA256SUM SHA256SUM.asc

## Create Checksum
## List of file types: "my*.asc my*.txt my*.sh"
FILES="my*.asc my*.txt my*.sh"
echo "sha256sum $FILES > SHA256SUM"
sha256sum my* > SHA256SUM

## Verify Checksum
echo "# ################ CHECKSUM ###### #########"
echo "sha256sum -c SHA256SUM"
sha256sum -c SHA256SUM 

## Sign Checksum
echo "# ################# SIGNING CHECKSUM ######### ######### ########"
echo "gpg --output SHA256SUM.asc --armor --sign --detach-sign SHA256SUM"
gpg --output SHA256SUM.asc --armor --sign --detach-sign SHA256SUM

## Verify Signature
echo "# ################# VERIFY ######### ######### ######### ########"
echo "gpg --verify SHA256SUM.asc SHA256SUM"
gpg --verify SHA256SUM.asc SHA256SUM

## Verify Assignments
if [ ! -f "my$WEEKS.tar.bz2.asc" ]; then
  echo "File does not exist"
  exit 1
elif [ $VERBOSE -eq 1 ]; then
  echo "File exists"

  ## Set the file name to check
  filename="my$WEEKS.tar.bz2.asc"

  ## Git works
  if [ GIT -eq 1 ] ; then 
    echo "Git Check"

    ## Check if the file is tracked by Git
    if git ls-files --error-unmatch "$filename" >/dev/null 2>&1; then
      echo "The file $filename is tracked by Git."
    else
      echo "WARNING: The file $filename is NOT tracked by Git!"
    fi
    
    git ls-tree -r HEAD --name-only
    git status
  fi
  
  ## Check if file is tracked by SHA256SUM
  if grep -q "$filename" "SHA256SUM"; then
    echo "$filename is tracked in SHA256SUM"
  else
    echo "$filename is not tracked in SHA256SUM"
  fi
fi

echo ""
echo "==== ==== ==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
echo "==== ==== ==== ATTN: is this WEEK $WEEK ?? === ==== ==== ===="
echo "==== ==== ==== ==== ==== ==== ==== ==== ==== ==== ==== ===="
echo ""

exit 0
