#!/bin/bash

# Replace with your private key ID
private_key=6D59FA6B

# Replace with the recipient's public key ID
public_key=15403B20

# Replace with the path of the folder you want to encrypt
RESDIR="$HOME/RESULT/"

# Check Week
unset WEEK

if [[ $1 =~ ^([0-9]{1,2})$ ]]; then
  WEEK=$1
else 
  echo "No args/wrong format (Expected: dd)"

  echo "Checking Week"
  echo "Getting Local Week"
  string=$(grep -oP 'W\d{2}' $HOME/.brew/.week)

  unset WEEK WEEKL WEEKS
  # Check if the string is not empty
  if [ ! -z "$string" ]; then
    if [[ $string =~ ^W([0-9]+)$ ]]; then
      # Extract the number from the input
      WEEKL=${BASH_REMATCH[1]}
    fi
  fi

  echo "Getting Server Week"
  WEEKURL="https://os.vlsm.org/WEEK/WEEK.txt"
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
  WEEKS=$II

  if ((WEEKL - WEEKS == 0)); then
    WEEK=$WEEKS
  else 
    echo "Local week and Server week are different"
    echo "Use myscript.sh 00(week)"
    exit 1
  fi

#  echo "$WEEK v $WEEKL v $WEEKS"
fi

# Is this the correct WEEK?
read -r -p "Is this WEEK $WEEK? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        ;;
    *)
        echo "It is not Week $WEEK!"
        echo "myscript.sh 00(week)"
        ;;
esac

str_week=$(printf "W%02d" $WEEK)

if ![[ $(head -n 1 $HOME/git/os231/TXT/myupdate.txt | tail -c 4) == "$str_week" ]]; then
  echo "myupdate.txt is of a different week!"
  cat $HOME/git/os231/TXT/myupdate.txt
  read -p "Are you sure you want to continue? (y/n)" ans
  if ! [[ $ans =~ y ]]; then
    echo "log cancled"
    exit 0
  fi
else
  echo "myupdate.txt is of same week, continuing..."
fi

folder_path=$RESDIR/$str_week

# Compress the folder into a tarball
tar cfj my$str_week.tar.bz2 $folder_path

# Encrypt the tarball using the private key and recipient's public key
gpg --armor --output my$str_week.tar.bz2.asc --encrypt --recipient $public_key --sign --recipient $private_key my$str_week.tar.bz2

# Delete the original tarball
rm $HOME/git/os231/TXT/my$str_week.tar.bz2 my$str_week.tar.bz2

cp my$str_week.tar.bz2.asc $HOME/git/os231/TXT/my$str_week.tar.bz2.asc

echo "Clean Repo"
rm -f SHA256sum SHA256sum.asc

echo "Create SHA256sum and Checksum"
# List of file types: "my*.asc my*.txt my*.sh"
FILES="my*.asc my*.txt my*.sh"
sha256sum -c $FILES > SHA256sum
sha256sum -c SHA256sum 

echo "Signing"
gpg --output SHA256sum.asc --armor --sign --detach-sign SHA256sum

echo "Verification"
gpg --verify SHA256sum.asc SHA256sum

echo "myscript.sh  finished"
echo "===== $str_week ====="
exit 0
