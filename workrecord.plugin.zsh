#!/usr/bin/env zsh
FILEPREFIX=/tmp/wr_
RUNNING="$FILEPREFIX""running"
FINISHING="$FILEPREFIX""finishing"
FINISHED="$FILEPREFIX""finished"

function __wrsort () {
	fn=$1
	sort -M $fn -o $fn
	sed -i '/^$/d' $fn
}

function __wrmin() {
	fn=$1
	__wrsort "$fn"
	cat "$fn"|head -1
}

function __wrman() {
	fn=$1
	__wrsort "$fn"
	cat "$fn"|tail -1
}

# Work record drop
function wrd () {
	t=$(__wrmin $RUNNING)
	echo "Sure you want to drop current task ? [y/n]"
	echo "$t"
	read yn
	if [[ "$yn" =~ '(y|Y)' ]]; then
		sed -i '1d' $RUNNING
		echo "Unfinished $t" >> $FINISHED
	fi
}

# Work record append
function wra () {
	if ! [ -e $RUNNING ]; then
		touch $RUNNING
	fi
	if [ "$#" -ne 2 ]; then
		return 1
	fi

	if ! due_time=$(date -d "+$1 min"); then
		return 1
	fi

	echo -n "$due_time\t"  >> $RUNNING
	echo "$2" >> $RUNNING
}

# Work record prompt
function wrp () {
	GREEN='%{%F{green}%}'
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

# Work record show/prompt
function __wrs () {
	finishing_list=''
	remain=0
	while [ -s $RUNNING ]; do
		entry=$(__wrmin "$RUNNING")
		due_time=$(echo "$entry"|cut -c -28)
		due_time=$(date +%s -d "$due_time")
		now=$(date +%s)
		remain=$(((due_time - now + 59)/60))
		if [ "$remain" -gt 0 ]; then
			break
		fi
		if [ -z "$finishing_list" ]; then
			finishing_list+="$entry"
		else
			finishing_list+="\n$entry"
		fi
		sed -i '1d' $RUNNING
	done
	if [ -n "$finishing_list" ]; then
		echo "Task due: " >&2
		echo "$finishing_list"|tee -a "$FINISHING" >&2
	fi
	if [ -s $FINISHING ]; then
		entry=$(__wrmin "$FINISHING")
		due_time=$(echo "$entry"|cut -c -28)
		due_time=$(date +%s -d "$due_time")
		now=$(date +%s)
		passed=$(((now - due_time)/60))
		if [ "$passed" -gt 120 ]; then
			echo -e '\e[5mRemind! Unhandled finishing task' >&2
		fi
	fi
	if ! [ -s $RUNNING ]; then
		return 0
	fi
	case "$remain" in
		([0-9]) echo -e -n $BLINK$RED ;;
		([1-2][0-9]) echo -e -n $RED ;;
		([3-6][0-9]) echo -e -n  $MAGENTA ;;
		([7-9][0-9]|1[0-1][0-9]) echo -e -n $BROWN ;;
		*) echo -e -n $GREEN ;;
	esac
	entry=$(__wrmin $RUNNING | cut -c 30-)
	echo -e -n $entry
}

# Finishing work record handle
function wrh() {
	if ! [ -s "$FINISHING" ]; then
		echo 'No finishing task' >&2
		return 0
	fi
	__wrsort "$FINISHING"
	cp "$FINISHING" "$FINISHING""_OLD"
	cat "$FINISHING""_OLD" | while read task; do
		sed -i '1d' "$FINISHING"
		echo "$task. Finished Yet ? [y/n/ i(ignore rest)]"
		read yn < /dev/tty
		if [[ "$yn" =~ "(n|N)"  ]]; then
			echo "Reschedule within how many minutes ?  [d to drop]"
			read min < /dev/tty
			if [[ "$min" =~ "(d|D)" ]]; then
				echo "Unfinished $task" >> $FINISHED
			else
				wra $min "$task"
				echo "Rescheduled !" >&2
			fi
		elif [[ "$yn" =~ "(y|Y)" ]]; then
			echo "Finished $task" >> "$FINISHED"
			echo "Finished !" >&2
		elif [ "$yn" = "i" ]; then
			echo "$task" >> "$FINISHING"
			break
		fi
	done
}

