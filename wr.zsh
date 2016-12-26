FILEPREFIX=/tmp/wr_

function wra () {
	if ! [ -e $FILEPREFIX"running" ]; then
		touch $FILEPREFIX"running"
	fi
	if [ "$#" -ne 2 ]; then
		return 1
	fi

	if ! due_time=$(date -d "+$1 min"); then
		return 1
	fi

	echo -n "$due_time "  >> $FILEPREFIX"running"
	echo "$2" >> $FILEPREFIX"running"
}

function wrp () {
	GREEN='%{%F{red}%}'
	BROWN='%{%F{brown}%}'
	MAGENTA='%{%F{magenta}%}'
	RED='%{%F{red}%}'
	#BLINK='%{%F{red}%}'
	BLINK=''
	__wrs
}

# Work record show
function wrs () {
	GREEN='\e[32m'
	BROWN='\e[33m'
	MAGENTA='\e[35m'
	RED='\e[31m'
	BLINK='\e[5m'
	__wrs
}

function __wrs () {
	while [ -s $FILEPREFIX"running" ]; do
		sort -M $FILEPREFIX"running" -o $FILEPREFIX"running"
		due_time=$(cat $FILEPREFIX"running" | head -1 | cut -c -28 )
		due_time=$(date +%s -d "$due_time")
		now=$(date +%s)
		remain=$(((due_time - now + 59)/60))
		if [ "$remain" -gt 0 ]; then
			break
		fi
		entry=$(cat $FILEPREFIX"running"|head -1)
		if [ -z "$finishing_list" ]; then
			finishing_list="$entry"
		else
			finishing_list="$finishing_list"'\n'"$entry"
		fi
		sed -i '1d' $FILEPREFIX"running"
	done
	if [ -n "$finishing_list" ]; then
		echo "Task due: " >&2
		echo "$finishing_list"|tee -a $FILEPREFIX"finishing" >&2
	fi
	if [ -s $FILEPREFIX"finishing" ]; then
		sort -M $FILEPREFIX"finishing" -o $FILEPREFIX"finishing"
		due_time=$(cat $FILEPREFIX"finishing" | head -1 | cut -c -28 )
		due_time=$(date +%s -d "$due_time")
		now=$(date +%s)
		passed=$(((now - due_time)/60))
		echo $passed
		if [ "$passed" -gt 120 ]; then
			echo -e '\e[5mRemind ! Unhandled finishing task' >&2
		fi
	fi
	if ! [ -s $FILEPREFIX"running" ]; then
		return 0
	fi
	content=$(cat $FILEPREFIX"running"|head -1|cut -c 30-)
	case "$remain" in
		([0-9]) echo -e -n $BLINK$RED ;;
		([1-2][0-9]) echo -e -n $RED ;;
		([3-6][0-9]) echo -e -n  $MAGENTA ;;
		([7-9][0-9]|1[0-1][0-9]) echo -e -n $BROWN ;;
		*) echo -e -n $GREEN ;;
	esac
	echo -e -n $content
}

function wrh() {
	cat $FILEPREFIX"finishing" | while read task; do
		echo "$task. Finished Yet ? [y/n]"
		yn=''
		echo "FUCK" $ync
		while [ -z "$yn" ]; do
			# WHY DIDN"T STOP HERE?????????
			read yn
			yn='y'
			case "$yn" in
				Y|y)* yn='y'; break ;;
				N|n)* yn='n'; break ;;
				*) yn='' ;;
			esac
			echo -n $yn
		done
		if [ "$yn" = "n" ] || [ "$yn" = "N" ]; then
			echo "Reschedule within how many minutes ?  [Enter to drop]"
			read min
			if [[ "$min" =~ "" ]]; then
				echo -n 'Unfinished ' >> $FILEPREFIX"finished"
				cat $FILEPREFIX"finishing"|head -1|tee -a $FILEPREFIX"finished"
				sed -i '1d' $FILEPREFIX"finishing"
			else
				content=$(cat $FILEPREFIX"finishing"|head -1|cut -c 30-)
				wra $min "$content"
				echo "Rescheduled !" >&2
			fi
		else
			echo -n 'Finished ' >> $FILEPREFIX"finished"
			cat $FILEPREFIX"finishing"|head -1|tee -a $FILEPREFIX"finished"
			sed -i '1d' $FILEPREFIX"finishing"
			echo "Finished !" >&2
		fi
	done
}

command="$1"
shift
case "$command" in
	("append") wra "$@" ;;
	("show") wrs ;;
	("prompt") wrp ;;
	("handle") wrh ;;
esac
