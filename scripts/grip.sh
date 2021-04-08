#!/usr/bin/env bash
source ${HOME}/.bashrc
################################################################################

declare OUTPUT="_output"
declare INPUT=

declare SOURCE="/dev/sr0"
declare TRACKN="1"
declare A_LANG="en"
declare S_LANG=""

########################################

# https://www.axllent.org/docs/mencoder-dvd-to-mpeg4
#	https://how-to.fandom.com/wiki/How_to_rip_DVDs_with_mencoder
# Got unexpected packet after EOF
#	https://trac.mplayerhq.hu/ticket/2353
#	-afm ffmpeg
declare ENCODER="$(which mencoder)"
declare OPTIONS="-nocache"
#>>> OPTIONS+=" -mc 0 -noskip"
#>>> OPTIONS+=" -ofps 24000/1001"
#>>> OPTIONS+=" -ovc xvid -xvidencopts pass=1:bitrate=896"
OPTIONS+=" -ovc lavc -lavcopts vpass=1:vbitrate=768"
OPTIONS+=" -oac mp3lame -lameopts cbr:br=96" #>>> :vol=10"
#>>> OPTIONS+=" -oac lavc"
declare RIPOPTS=
declare CROPCHP="2"
declare CROPTST="30"

declare FILE=

################################################################################

declare RTYPE=
if [[ ${1} == -+([a-z]) ]]; then
	RTYPE="${1}"
	shift
fi

[[ ${1} == +([0-9])	]] && TRACKN="${1}"			&& shift
[[ ${1} == +([A-Za-z])	]] && A_LANG="${1}"			&& shift
[[ ${1} == +([A-Za-z])	]] && S_LANG="${1}"			&& shift
[[ -b ${1} || -f ${1}	]] && SOURCE="$(realpath -s ${1})"	&& shift

########################################

OUTPUT+=".$(basename ${SOURCE})"
OPTIONS+=" -passlogfile ${OUTPUT}.log"

INPUT="dvd://${TRACKN} -dvd-device ${SOURCE}"
if [[ -n ${S_LANG} ]]; then
	INPUT+=" -alang ${A_LANG} -slang ${S_LANG} -noautosub"
else
	INPUT+=" -alang ${A_LANG} -nosub -noautosub"
fi

################################################################################

function run_cmd {
	declare COMMAND="${1}" && shift
	echo -en "\e]0;"			1>&2
	echo -en "$(basename ${0}): ${COMMAND}"	1>&2
	echo -en "\a"				1>&2
	echo -en "\n"		1>&2
	printf "=%.0s" {1..80}	1>&2
	echo -en "\n"		1>&2
	echo -en "COMMAND: "	1>&2
	echo -en "${@}"		1>&2
	echo -en "\n"		1>&2
	printf "=%.0s" {1..80}	1>&2
	echo -en "\n"		1>&2
	"${@}" || return 1
	return 0
}

################################################################################

function dvd_rescue {
#>>>	run_cmd "${FUNCNAME}" $(which dcfldd) bs=2048 conv=noerror,notrunc,sync "${@}" if=${SOURCE} of=${OUTPUT} || return 1
	# this is straight from "info ddrescue" in the "Optical media: Copying CD-ROMs and DVDs" section
#>>>	run_cmd "${FUNCNAME}" $(which ddrescue) --no-scrape			--sector-size=2048 "${@}" ${SOURCE} ${OUTPUT} ${OUTPUT}.mapfile || return 1
#>>>	run_cmd "${FUNCNAME}" $(which ddrescue) --idirect --retry-passes=1	--sector-size=2048 "${@}" ${SOURCE} ${OUTPUT} ${OUTPUT}.mapfile || return 1
	run_cmd "${FUNCNAME}" $(which ddrescue) --idirect --no-scrape		--sector-size=2048 "${@}" ${SOURCE} ${OUTPUT} ${OUTPUT}.mapfile || return 1
	return 0
}

########################################

function vlc_encode {
	# https://wiki.videolan.org/VLC_HowTo/Rip_a_DVD
	#	https://en.wikibooks.org/wiki/MPlayer#Rip_DVD_to_raw_video
	#	https://www.naturalborncoder.com/miscellaneous/2012/01/31/adding-cover-art-to-video-files
	ENCODER="$(which vlc) -vvv --play-and-exit --no-repeat --no-loop --intf dummy"
#>>>	RIPOPTS=":sout='#transcode{vcodec=mp2v,vb=4096,acodec=mp2a,ab=192,scale=1,channels=2,deinterlace,audio-sync}:std{access=file, mux=ps,dst="${OUTPUT}.mpg"}'
	RIPOPTS=":sout='#transcode{vcodec=xvid,vb=896,acodec=mp3lame,ab=128,audio-sync,deinterlace}:standard{access=file,mux=ts,dst=${OUTPUT}.avi}'"
	RIPOPTS+=" vlc://quit"
	run_cmd "${FUNCNAME}" ${ENCODER} ${RIPOPTS} "${@}" dvdsimple://${SOURCE}\#${TRACKN} || return 1
	return 0
}

########################################

function mp_encode {
	declare CROP=
	RIPOPTS="${OPTIONS}"
	RIPOPTS="$(echo "${RIPOPTS}" | ${SED} "s|(-ovc) [^ ]+|\1 lavc|g")"
	RIPOPTS="$(echo "${RIPOPTS}" | ${SED} "s|(-oac) [^ ]+|\1 lavc|g")"
	RIPOPTS="${ENCODER} ${INPUT} ${RIPOPTS} -chapter ${CROPCHP} -endpos ${CROPTST} -vf cropdetect -o /dev/null"
	echo -en "\nDETECT: ${RIPOPTS}\n"
	${RIPOPTS} 2>/dev/null | ${SED} -n "s|^.+CROP.+crop=([0-9:]+).+$|\1|gp" | sort -u
	read -p "CROP: " CROP

	RIPOPTS="${OPTIONS}"
	RIPOPTS="$(echo "${RIPOPTS}" | ${SED} "s|(-oac) [^ ]+|\1 copy|g")"
	run_cmd "${FUNCNAME}: first pass" ${ENCODER} ${INPUT} ${RIPOPTS} -vf crop=${CROP} -o /dev/null || return 1

	RIPOPTS="${OPTIONS}"
	RIPOPTS="$(echo "${RIPOPTS}" | ${SED} "s|(pass)=[0-9]+|\1=2|g")"
	run_cmd "${FUNCNAME}: second pass" ${ENCODER} ${INPUT} ${RIPOPTS} -vf crop=${CROP} "${@}" -o ${OUTPUT}.avi || return 1

	return 0
}

################################################################################

  if [[ -z ${RTYPE} ]]; then		mp_encode	"${@}" || exit 1
elif [[ ${RTYPE} == -d ]]; then		dvd_rescue	"${@}" || exit 1
elif [[ ${RTYPE} == -v ]]; then		vlc_encode	"${@}" || exit 1
elif [[ ${RTYPE} == -m ]]; then		mp_encode	"${@}" || exit 1
fi

exit 0
################################################################################
# end of file
################################################################################
