#!/usr/bin/env bash
source ${HOME}/.bashrc
################################################################################

declare OUTPUT="_output"
declare INPUT=

declare SOURCE="/dev/sr0"
declare TRACKN="1"
declare A_LANG="en"
declare S_LANG=""

################################################################################

declare DATE="${DATE:-$(date --iso)}"

declare SECOND_PER_MINUTE="60"
declare FRAMES_PER_SECOND="75"

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

########################################

declare CDDB_SERVER="gnudb.org"
declare CDDB="-1"

declare PARANOIA_OPTS="proof"
declare CD_SPEED="6"
declare CD_SPEED_RESCUE="1"

declare FLAC_MANY="Various Artists"
declare FLAC_TDIV=" \/\/ "	# no dashes (-); they will break the regular expression validation below
declare FLAC_ADIV="\; "		# no dashes (-); they will break the regular expression validation below
declare FLAC_NDIV="\. "		# no dashes (-); they will break the regular expression validation below
declare FLAC_INDX= #>>> "-- "
declare FLAC_ISEP="^"

declare FLAC_HASH_CHARS="[0-9a-f]{40}"
declare FLAC_HASH="sha1sum"
declare FLAC_BLCK="8"

declare ID_NAME=
declare ID_FILE_CHARS="-#+:=${FLAC_ISEP}"
declare ID_EXTR_CHARS="():;,&!?%'"
declare ID_ESCP_CHARS="&"
declare ID_NAME_CHARS="[-._a-zA-Z0-9+]+"
declare ID_TITL_CHARS="$(echo "${ID_NAME_CHARS}" | ${SED} "s|\]\+?$||g")${FLAC_TDIV//\\}${FLAC_NDIV//\\}${ID_EXTR_CHARS}]+"
declare ID_ARTS_CHARS="$(echo "${ID_NAME_CHARS}" | ${SED} "s|\]\+?$||g")${FLAC_ADIV//\\}${ID_EXTR_CHARS}]+"
declare ID_YEAR_CHARS="[0-9]{4}"
declare ID_TRCK_CHARS="[0-9]{2}"

# bracket detection, along with all the other charaacters, is very involved, so not doing that
# thus, brackets are not allowed, at all, anywhere
declare FILEALL_CHARS=
FILEALL_CHARS+="["
FILEALL_CHARS+="${ID_FILE_CHARS}"
FILEALL_CHARS+="${ID_EXTR_CHARS}"
FILEALL_CHARS+="$(echo "${ID_NAME_CHARS}" | ${SED} -e "s|^\[-?||g" -e "s|-?\]\+?$||g")"
FILEALL_CHARS+="$(echo "${ID_TITL_CHARS}" | ${SED} -e "s|^\[-?||g" -e "s|-?\]\+?$||g")"
FILEALL_CHARS+="$(echo "${ID_ARTS_CHARS}" | ${SED} -e "s|^\[-?||g" -e "s|-?\]\+?$||g")"
FILEALL_CHARS+="]"

declare ID_FCVR=
declare ID_BCVR=
declare ID_MCVR=

declare ID_CODE= ; declare ID_CODE_CHARS="[0-9]{13}"
declare ID_DISC= ; declare ID_DISC_CHARS="[a-zA-Z0-9_.-]{28}"
declare ID_MBID= ; declare ID_MBID_CHARS="[0-9a-f-]{36}"
declare ID_COGS= ; declare ID_COGS_CHARS="m?[0-9]+"

########################################

declare IMAGE_CMD="feh --scale-down --geometry 800x600"
declare FLAC_OPTS="
	--force \
	--verify \
	--warnings-as-errors \
	\
	--best \
	--no-padding \
	--no-preserve-modtime
"
export XZ_OPT="]
	--verbose \
	--threads=0 \
	--extreme -9
"

########################################

declare FILE=

################################################################################

declare RTYPE=
if [[ ${1} == -+([a-z]) ]]; then
	RTYPE="${1}"
	shift
fi

if [[ ${RTYPE} != -[lry] ]]; then
	[[ ${1} == +([0-9])	]] && TRACKN="${1}"				&& shift
	[[ ${1} == +([A-Za-z])	]] && A_LANG="${1}"				&& shift
	[[ ${1} == +([A-Za-z])	]] && S_LANG="${1}"				&& shift
	[[ -b ${1} || -f ${1}	]] && SOURCE="$(realpath --no-symlinks ${1})"	&& shift
fi

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
	declare MARKER="${1}" && shift
	echo -en "\e]0;"			1>&2
	echo -en "$(basename ${0}): ${MARKER}"	1>&2
	echo -en "\a"				1>&2
	echo -en "\n"				1>&2
	printf "=%.0s" {1..80}			1>&2
	echo -en "\n"				1>&2
	if [[ -n ${@} ]]; then
		echo -en "=== ${@}"		1>&2
	else
		echo -en "--- ${MARKER} ---"	1>&2
	fi
	echo -en "\n"				1>&2
	printf "=%.0s" {1..80}			1>&2
	echo -en "\n"				1>&2
	"${@}" || return 1
	return 0
}

########################################

function divider {
	printf "+%.0s" {1..40}	1>&2
	echo -en "\n"		1>&2
	return 0
}

########################################

function namer {
#>>>		${GREP} -o "[a-z0-9_-]" |
	echo -en "${@}" |
		${SED} \
			-e "s|!||g" \
			-e "s|'||g" \
			-e "s|,||g" \
			-e "s|/|-|g" \
			-e "s|\&|+|g" \
			-e "s|: |-|g" \
			-e "s| \(|-|g" -e "s|\)||g" \
			-e "s|[[:space:]]+|_|g" \
		| tr 'A-Z' 'a-z' \
		| tr -d '\n'
	return 0
}

########################################

function meta_get {
	declare META=".metadata"
	if [[ -f ${1} ]]; then
		META="${1}"
		shift
	fi
	${SED} -n "s|^${1}:?[[:space:]]+(.+)$|\1|gp" ${META} 2>/dev/null | head -n1
	return 0
}

########################################

function meta_set {
	declare META=".metadata"
	if [[ -f ${1} ]]; then
		META="${1}"
		shift
	fi
	${SED} -i "s|^(${1}:?).*$|\1 ${2}|g" ${META}
	return 0
}

########################################

function strip_file {
	declare STRIP="${1}" && shift
	${SED} "/^[[:space:]]*$/d" ${STRIP} | tr -d '\n' >${STRIP}.${FUNCNAME}
	${MV} ${STRIP}.${FUNCNAME} ${STRIP}
	return 0
}

########################################

function go_fetch {
	declare LCL="${1}" && shift
	declare RMT="${1}" && shift
	declare SLP="$(((${RANDOM}%10)+3))"
	declare AGT="${SCRIPT}/${DATE} (${USER}@${HOSTNAME}.net)"
	run_cmd "${FUNCNAME}" ${WGET_C}		--user-agent="${AGT}" --output-document="${LCL}" "${RMT}"			||
	run_cmd "${FUNCNAME}" $(which curl)	--user-agent "${AGT}" --verbose --remote-time --output "${LCL}" "${RMT}"	|| return 1
	echo -en "sleeping for "
	while (( ${SLP} > 0 )); do
		echo -en "${SLP}, "
		sleep 1
		SLP="$((${SLP}-1))"
	done
	echo -en "done.\n"
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
	# https://www.themoviedb.org
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
	read -p "CROP> " CROP

	RIPOPTS="${OPTIONS}"
	RIPOPTS="$(echo "${RIPOPTS}" | ${SED} "s|(-oac) [^ ]+|\1 copy|g")"
	run_cmd "${FUNCNAME}: first pass" ${ENCODER} ${INPUT} ${RIPOPTS} -vf crop=${CROP} -o /dev/null || return 1

	RIPOPTS="${OPTIONS}"
	RIPOPTS="$(echo "${RIPOPTS}" | ${SED} "s|(pass)=[0-9]+|\1=2|g")"
	run_cmd "${FUNCNAME}: second pass" ${ENCODER} ${INPUT} ${RIPOPTS} -vf crop=${CROP} "${@}" -o ${OUTPUT}.avi || return 1

	return 0
}

########################################

function cd_export {
	# https://linuxconfig.org/how-to-rip-an-audio-cd-from-the-command-line-using-cdparanoia
	#	https://www.cyberciti.biz/faq/linux-ripping-and-encoding-audio-files
	run_cmd "${FUNCNAME}" $(which cdparanoia) --verbose --output-wav --batch --abort-on-skip --never-skip=10 "${@}" --force-cdrom-device ${SOURCE} || return 1
	return 0
}

########################################

function cd_cuefile {
	declare TTL_M="00"
	declare TTL_S="00"
	declare TTL_F="00"
	declare TRACK=
	declare IDX_M=
	declare IDX_S=
	declare IDX_F=
	shopt -s lastpipe
	cdir -D -n -d ${SOURCE} 1>&2; echo -en "\n" 1>&2
	cdir -D -n -d ${SOURCE} 2>/dev/null | ${GREP} -v -e "[a-z]" -e "\[DATA\]" | while read -r FILE; do
		TRACK="$(echo "${FILE}" | ${SED} "s|^[[:space:]]*([0-9]+)\:([0-9]+)\.([0-9]+)[[:space:]]+([0-9]+).*$|\4|g")"; if [[ ${TRACK} == [0-9] ]]; then TRACK="0${TRACK}"; fi
		IDX_M="$(echo "${FILE}" | ${SED} "s|^[[:space:]]*([0-9]+)\:([0-9]+)\.([0-9]+)[[:space:]]+([0-9]+).*$|\1|g")"; if [[ ${IDX_M} == [0-9] ]]; then IDX_M="0${IDX_M}"; fi
		IDX_S="$(echo "${FILE}" | ${SED} "s|^[[:space:]]*([0-9]+)\:([0-9]+)\.([0-9]+)[[:space:]]+([0-9]+).*$|\2|g")"; if [[ ${IDX_S} == [0-9] ]]; then IDX_S="0${IDX_S}"; fi
		IDX_F="$(echo "${FILE}" | ${SED} "s|^[[:space:]]*([0-9]+)\:([0-9]+)\.([0-9]+)[[:space:]]+([0-9]+).*$|\3|g")"; if [[ ${IDX_F} == [0-9] ]]; then IDX_F="0${IDX_F}"; fi
		echo -en "  TRACK ${TRACK} AUDIO\n"
		echo -en "    INDEX 01 ${TTL_M}:${TTL_S}:${TTL_F}\n"
		echo -en "           + ${IDX_M}:${IDX_S}:${IDX_F}\n" 1>&2
		echo -en "\n" 1>&2
		TTL_F="${TTL_F/#0}"; IDX_F="${IDX_F/#0}";
		TTL_S="${TTL_S/#0}"; IDX_S="${IDX_S/#0}";
		TTL_M="${TTL_M/#0}"; IDX_M="${IDX_M/#0}";
		TTL_F="$((${TTL_F}+${IDX_F}))"; (( ${TTL_F} >= ${FRAMES_PER_SECOND} )) && { TTL_S="$((${TTL_S}+1))"; TTL_F="$((${TTL_F}-${FRAMES_PER_SECOND}))"; }
		TTL_S="$((${TTL_S}+${IDX_S}))"; (( ${TTL_S} >= ${SECOND_PER_MINUTE} )) && { TTL_M="$((${TTL_M}+1))"; TTL_S="$((${TTL_S}-${SECOND_PER_MINUTE}))"; }
		TTL_M="$((${TTL_M}+${IDX_M}))";
		if [[ ${TTL_M} == [0-9] ]]; then TTL_M="0${TTL_M}"; fi
		if [[ ${TTL_S} == [0-9] ]]; then TTL_S="0${TTL_S}"; fi
		if [[ ${TTL_F} == [0-9] ]]; then TTL_F="0${TTL_F}"; fi
	done
	echo -en "      TOTAL: ${TTL_M}:${TTL_S}:${TTL_F}\n" 1>&2
	return 0
}

########################################

# merge wav files
#	shnjoin -D -O always -i wav -o wav -e -a .audio.shn. *.wav
#	sox -V4 --show-progress --ignore-length --type wav --combine concatenate *.wav .audio.sox.wav
#	diff .audio.*.wav
# extract cue file
#	shncue -D -i wav -c *.wav >.audio.cue
#	cat .audio.cue
#	cdir -D -n -d /dev/sr0

function cd_encode {
	# https://www.linux-magazine.com/Issues/2018/207/FLAC-The-premier-digital-audio-codec
	#	https://xiph.org/flac/documentation_tools_flac.html
	#	https://xiph.org/vorbis/doc/v-comment.html
	#	https://wiki.xiph.org/Metadata
	#	https://wiki.xiph.org/Chapter_Extension
	#		https://trac.videolan.org/vlc/ticket/6895
	#		https://trac.ffmpeg.org/ticket/1833
	#		https://git.videolan.org/?p=vlc.git;a=commitdiff;h=cab4efd532bb656b5bc7dc85f557179bf0a908a0
	#		https://git.videolan.org/?p=vlc.git;a=commitdiff;h=d9b1afb30594f3dca65aa8ac7ef93b400f24faff
	# https://en.wikipedia.org/wiki/Cue_sheet_(computing)
	#	https://musicbrainz.org/doc/Cover_Art_Archive/API
	#		https://hydrogenaud.io/index.php?topic=60122.0
	#	https://wiki.archlinux.org/index.php/CUE_Splitting
	# https://www.izotope.com/en/learn/digital-audio-basics-sample-rate-and-bit-depth.html
	if [[ ! -s .metadata ]]; then
		cat /dev/null	>.metadata
		printf "%-40.40s" "### file $(divider 2>&1)" >>.metadata
		echo ""		>>.metadata
		echo "NAME:"	>>.metadata
		echo "FCVR:"	>>.metadata
		echo "BCVR:"	>>.metadata
		echo "MCVR:"	>>.metadata
		echo "NULL:"	>>.metadata
		printf "%-40.40s" "### meta $(divider 2>&1)" >>.metadata
		echo ""		>>.metadata
		echo "CODE:"	>>.metadata
		echo "DISC:"	>>.metadata
		echo "MBID:"	>>.metadata
		echo "COGS:"	>>.metadata
		printf "%-40.40s" "### tags $(divider 2>&1)" >>.metadata
		echo ""		>>.metadata
	fi
	run_cmd "${FUNCNAME}" cat .metadata

	if [[ ${1} == -s ]]; then
		shift
		declare SAFE_LIST="
			.metadata
			\
			.exported
			.audio.log
			.audio.cue
			audio.cue
			audio.wav
			\
			_audio.cue
		"
		run_cmd "${FUNCNAME}" ${LL} --directory ${SAFE_LIST}
		run_cmd "${FUNCNAME}" ${LL} --directory $(
			eval find ./ -maxdepth 1 -empty \
			| ${SED} "s|^\./||g" | sort
		)
		run_cmd "${FUNCNAME}" ${LL} --directory $(
			eval find ./ -maxdepth 1 $(
				for FILE in ${SAFE_LIST}; do
					echo "\\( -path ./${FILE} -prune \\) -o "
				done
				for FILE in $(meta_get NAME); do
					echo "\\( -path ./${FILE}.\* -prune \\) -o "
				done
				) -print \
			| ${SED} "s|^\./||g" | sort
		)
		return 0
	fi

	if {
		[[ ! -s .exported	]] ||
		[[ ! -s .audio.log	]] ||
		[[ ! -s .audio.cue	]] ||
		[[ ! -s audio.cue	]] ||
		[[ ! -s audio.wav	]];
	}; then
		run_cmd "${FUNCNAME}: audio"
		cat /dev/null >.audio.log
#>>> version (cdda) >
		run_cmd "${FUNCNAME}: audio" $(which cdparanoia)	--version	2>&1 | tee -a .audio.log
		run_cmd "${FUNCNAME}: audio" $(which cdda2wav)		--version	2>&1 | tee -a .audio.log
#>>> version (cdda) <
#>>> version (shntool) >
#		run_cmd "${FUNCNAME}: audio" $(which shntool)		-v		2>&1 | tee -a .audio.log
#>>> version (shntool) <
#>>> version (cdda/cdir) >
		run_cmd "${FUNCNAME}: audio" $(which cdir)		-V		2>&1 | tee -a .audio.log
		run_cmd "${FUNCNAME}: audio" $(which cdir) \
			-D -n -d ${SOURCE} \
			2>&1 | tee -a .audio.log
			[[ ${PIPESTATUS[0]} != 0 ]] && return 1
#>>> version (cdda/cdir) <
#>>> cue (cdir) >
#		echo -en "FILE \"audio.wav\" WAVE\n" >audio.cue
#		run_cmd "${FUNCNAME}: audio" cd_cuefile					2>&1 | tee -a .audio.log
#		run_cmd "${FUNCNAME}: audio" cd_cuefile \
#			>>audio.cue 2>/dev/null
#>>> cue (cdir) <
#>>> cue (shntool) >
#		run_cmd "${FUNCNAME}: audio" $(which shncue) \
#			-D -i wav -c audio_*.wav \
#			2>&1 | tee -a .audio.log
#			[[ ${PIPESTATUS[0]} != 0 ]] && return 1
#		run_cmd "${FUNCNAME}: audio" $(which shncue) \
#			-i wav -c audio_*.wav \
#			>audio.cue 2>/dev/null
#		${SED} -i \
#			-e "s|^(FILE \").+(\" WAVE)$|\1audio.wav\2|g" \
#			-e "s|^(    INDEX [0-9]{2} )([0-9]:.+)$|\10\2|g" \
#			audio.cue
#>>> cue (shntool) <
#>>> wav/cue (cdda) >
		run_cmd "${FUNCNAME}: audio" $(which cdda2wav) \
			-verbose-level all \
			-speed ${CD_SPEED} \
			-paranoia \
			-paraopts ${PARANOIA_OPTS} \
			-cddb ${CDDB} \
			-cddbp-server ${CDDB_SERVER} \
			-output-format wav \
			-track all \
			-cuefile \
			-device ${SOURCE} \
			2>&1 | tee -a .audio.log
			[[ ${PIPESTATUS[0]} != 0 ]] && return 1
#>>> wav/cue (cdda) <
#>>> wav/cue (cdda/shntool) >
#		run_cmd "${FUNCNAME}: audio" $(which cdda2wav) \
#			-verbose-level all \
#			-speed ${CD_SPEED_RESCUE} \
#			-paranoia \
#			-paraopts ${PARANOIA_OPTS} \
#			-output-format wav \
#			-alltracks \
#			-cuefile \
#			-device ${SOURCE} \
#			2>&1 | tee -a .audio.log
#			[[ ${PIPESTATUS[0]} != 0 ]] && return 1
#>>> wav/cue (cdda/shntool) <
#>>> wav (shntool) >
#		run_cmd "${FUNCNAME}: audio" $(which shnjoin) \
#			-D -O always -i wav -o wav -e -a audio audio_*.wav \
#			2>&1 | tee -a .audio.log
#			[[ ${PIPESTATUS[0]} != 0 ]] && return 1
#>>> wav (shntool) <
		run_cmd "${FUNCNAME}: audio"
		${RSYNC_U} --checksum audio.cue .audio.cue		|| return 1
		${SED} -i \
			-e "/^REM/d" \
			-e "/^    FLAGS /d" \
			-e "/^    ISRC /d" \
			-e "/^    PREGAP /d" \
			audio.cue					|| return 1
		if ! diff ${DIFF_OPTS} .audio.cue audio.cue; then
			${RSYNC_U} --checksum audio.cue _audio.cue	|| return 1
		fi
		echo "${DATE}" >.exported
	fi

	for FILE in $(meta_get NULL); do
		if [[ ! -f ${FILE}.null ]]; then
			touch ${FILE}.null
		fi
	done

	if ! run_cmd "${FUNCNAME}: output" diff ${DIFF_OPTS} .audio.cue audio.cue; then
		if ! run_cmd "${FUNCNAME}: output" diff ${DIFF_OPTS} _audio.cue audio.cue; then
			return 1
		fi
	elif ${LL} _audio.cue 2>/dev/null; then
		return 1
	fi

	ID_CODE="$(meta_get CODE)"
	if {
		[[ -z $(echo "${ID_CODE}" | ${GREP} -o "^${ID_CODE_CHARS}$") ]] &&
		[[ ${ID_CODE} != null ]];
	}; then
		run_cmd "${FUNCNAME}: code"
		echo -en "BARCODE: $(which cdda2wav) -info-only -device ${SOURCE}\n"
		FILE="$(${SED} -n "s|^CATALOG (.+)$|\1|gp" audio.cue)"
		if [[ -n ${FILE} ]]; then
			echo -en "BARCODE: ${FILE} (audio.cue)\n"
		fi
		if [[ -n ${ID_CODE} ]]; then
			echo -en "BARCODE: ${ID_CODE}\n"
		fi
		read -p "BARCODE> " ID_CODE
		if {
			[[ -z $(echo "${ID_CODE}" | ${GREP} -o "^${ID_CODE_CHARS}$") ]] &&
			[[ ${ID_CODE} != null ]];
		}; then
			return 1
		fi
		meta_set CODE ${ID_CODE}
	fi
	if [[ $(meta_get audio.cue CATALOG) != ${ID_CODE} ]]; then
		run_cmd "${FUNCNAME}: code"
		if [[ -z $(${GREP} "^CATALOG" audio.cue) ]]; then
			${SED} -i "s|^(FILE .+)$|CATALOG ${ID_CODE}\n\1|g" audio.cue
		else
			meta_set audio.cue CATALOG ${ID_CODE}
		fi
		${RSYNC_U} --checksum audio.cue _audio.cue || return 1
	fi

	ID_DISC="$(meta_get DISC)"
	if {
		[[ -z $(echo "${ID_DISC}" | ${GREP} -o "^${ID_DISC_CHARS}$") ]] &&
		[[ ${ID_DISC} != null ]];
	}; then
		run_cmd "${FUNCNAME}: disc"
		echo -en "CDINDEX: $(which cdda2wav) -info-only -device ${SOURCE}\n"
		if [[ -n ${ID_DISC} ]]; then
			echo -en "CDINDEX: ${ID_DISC}\n"
		fi
		read -p "CDINDEX> " ID_DISC
		if {
			[[ -z $(echo "${ID_DISC}" | ${GREP} -o "^${ID_DISC_CHARS}$") ]] &&
			[[ ${ID_DISC} != null ]];
		}; then
			return 1
		fi
		meta_set DISC ${ID_DISC}
	fi

	ID_MBID="$(meta_get MBID)"
	if { {
		[[ ${ID_CODE} != null ]];
	} && {
		{ [[ ! -s mb.${ID_CODE}.html ]] && [[ ! -f mb.${ID_CODE}.html.null ]]; };
	}; }; then
		run_cmd "${FUNCNAME}: mbid"
		run_cmd "${FUNCNAME}: mbid" go_fetch "mb.${ID_CODE}.html" "https://musicbrainz.org/search?advanced=1&type=release&query=barcode:${ID_CODE}" || return 1
		strip_file mb.${ID_CODE}.html
		if {
			{ [[ ! -s mb.${ID_CODE}.html ]] && [[ ! -f mb.${ID_CODE}.html.null ]]; };
		}; then
			${LL} mb.${ID_CODE}.html*
			return 1
		fi
	fi
	if { {
		[[ ${ID_DISC} != null ]];
	} && {
		{ [[ ! -s mb.${ID_DISC}.html ]] && [[ ! -f mb.${ID_DISC}.html.null ]]; };
	}; }; then
		run_cmd "${FUNCNAME}: mbid"
		run_cmd "${FUNCNAME}: mbid" go_fetch "mb.${ID_DISC}.html" "https://musicbrainz.org/cdtoc/${ID_DISC}" || return 1
		strip_file mb.${ID_DISC}.html
		if {
			{ [[ ! -s mb.${ID_DISC}.html ]] && [[ ! -f mb.${ID_DISC}.html.null ]]; };
		}; then
			${LL} mb.${ID_DISC}.html*
			return 1
		fi
	fi
	if {
		[[ -z $(echo "${ID_MBID}" | ${GREP} -o "^${ID_MBID_CHARS}$") ]] &&
		[[ ${ID_MBID} != null ]];
	}; then
		run_cmd "${FUNCNAME}: mbid"
		declare MBIDS=($(
			${SED} "s|(<a href=\"/release/${ID_MBID_CHARS}\")|\n\1|g" mb.${ID_CODE}.html mb.${ID_DISC}.html |
			${SED} -n "s|^.+/release/(${ID_MBID_CHARS}).+>([A-Z]{2})<.+$|\2:\1|gp" |
			sort -u
		))
		for FILE in ${MBIDS[@]}; do
			echo -en "${FILE/%:*}: https://musicbrainz.org/release/${FILE/#*:}\n"
		done
		if [[ -n ${ID_MBID} ]]; then
			echo -en "MBID: ${ID_MBID}\n"
		fi
		read -p "MBID> " ID_MBID
		ID_MBID="${ID_MBID/#*\/}"
		if {
			[[ -z $(echo "${ID_MBID}" | ${GREP} -o "^${ID_MBID_CHARS}$") ]] &&
			[[ ${ID_MBID} != null ]];
		}; then
			return 1
		fi
		meta_set MBID ${ID_MBID}
	fi
	if { {
		[[ ${ID_MBID} != null ]];
	} && {
		{ [[ ! -s id.${ID_MBID}.html ]] && [[ ! -f id.${ID_MBID}.html.null ]]; };
	}; }; then
		run_cmd "${FUNCNAME}: mbid"
		run_cmd "${FUNCNAME}: mbid" go_fetch "id.${ID_MBID}.html" "https://musicbrainz.org/release/${ID_MBID}" || return 1
		strip_file id.${ID_MBID}.html
		if {
			{ [[ ! -s id.${ID_MBID}.html ]] && [[ ! -f id.${ID_MBID}.html.null ]]; };
		}; then
			${LL} id.${ID_MBID}.html*
			return 1
		fi
	fi
	if { {
		[[ ${ID_MBID} != null ]];
	} && {
		{ [[ ! -s id.${ID_MBID}.json ]] && [[ ! -f id.${ID_MBID}.json.null ]]; };
	}; }; then
		run_cmd "${FUNCNAME}: mbid"
		run_cmd "${FUNCNAME}: mbid" go_fetch "id.${ID_MBID}.json" "https://musicbrainz.org/ws/2/release/${ID_MBID}?inc=aliases+artist-credits+labels+discids+recordings&fmt=json" || return 1
		strip_file id.${ID_MBID}.json
		if {
			{ [[ ! -s id.${ID_MBID}.json ]] && [[ ! -f id.${ID_MBID}.json.null ]]; };
		}; then
			${LL} id.${ID_MBID}.json*
			return 1
		fi
	fi

	ID_COGS="$(meta_get COGS)"
	if {
		[[ -z $(echo "${ID_COGS}" | ${GREP} -o "^${ID_COGS_CHARS}$") ]] &&
		[[ ${ID_COGS} != null ]];
	}; then
		run_cmd "${FUNCNAME}: cogs"
		if [[ ${ID_CODE} != null ]]; then
			echo -en "DISCOGS (url): https://www.discogs.com/search/?type=release&q=${ID_CODE}\n"
		fi
		if [[ -n ${ID_COGS} ]]; then
			if [[ ${ID_COGS//[0-9]} == m ]]; then	echo -en "DISCOGS (url): https://www.discogs.com/master/${ID_COGS/#m}\n"
			else					echo -en "DISCOGS (url): https://www.discogs.com/release/${ID_COGS}\n"
			fi
		fi
		read -p "DISCOGS (url)> " ID_COGS
		if [[ -n $(echo "${ID_COGS}" | ${GREP} "/master/") ]]; then	ID_COGS="m${ID_COGS/#*\/}"
		else								ID_COGS="${ID_COGS/#*\/}"
		fi
		if {
			[[ -z $(echo "${ID_COGS}" | ${GREP} -o "^${ID_COGS_CHARS}$") ]] &&
			[[ ${ID_COGS} != null ]];
		}; then
			return 1
		fi
		meta_set COGS ${ID_COGS}
	fi
	if { {
		[[ ${ID_COGS} != null ]];
	} && {
		{ [[ ! -s id.${ID_COGS}.html ]] && [[ ! -f id.${ID_COGS}.html.null ]]; };
	}; }; then
		run_cmd "${FUNCNAME}: cogs"
		if [[ ${ID_COGS//[0-9]} == m ]]; then	run_cmd "${FUNCNAME}: cogs" go_fetch "id.${ID_COGS}.html" "https://www.discogs.com/master/${ID_COGS/#m}" || return 1
		else					run_cmd "${FUNCNAME}: cogs" go_fetch "id.${ID_COGS}.html" "https://www.discogs.com/release/${ID_COGS}" || return 1
		fi
		strip_file id.${ID_COGS}.html
		if {
			{ [[ ! -s id.${ID_COGS}.html ]] && [[ ! -f id.${ID_COGS}.html.null ]]; };
		}; then
			${LL} id.${ID_COGS}.html*
			return 1
		fi
	fi

	ID_FCVR="$(meta_get FCVR)"
	ID_BCVR="$(meta_get BCVR)"
	ID_MCVR="$(meta_get MCVR)"
	if { {
		[[ ${ID_MBID} != null ]];
	} && {
		{ [[ ! -f $(${LS} _image.${ID_MBID}.[0-9-]* 2>/dev/null | tail -n1) ]] ||
		[[ ! -s image.${ID_MBID}.json ]]; } && [[ ! -f image.${ID_MBID}.json.null ]];
	}; }; then
		run_cmd "${FUNCNAME}: images"
		run_cmd "${FUNCNAME}: images" go_fetch "image.${ID_MBID}.json"		http://coverartarchive.org/release/${ID_MBID}		|| return 1
#>>>		run_cmd "${FUNCNAME}: images" go_fetch "image.${ID_MBID}.front.jpg"	http://coverartarchive.org/release/${ID_MBID}/front	|| return 1
#>>>		run_cmd "${FUNCNAME}: images" go_fetch "image.${ID_MBID}.back.jpg"	http://coverartarchive.org/release/${ID_MBID}/back	|| return 1
		strip_file image.${ID_MBID}.json
		if {
			{ [[ ! -s image.${ID_MBID}.json ]] && [[ ! -f image.${ID_MBID}.json.null ]]; };
		}; then
			${LL} image.${ID_MBID}.json*
			return 1
		fi
		declare IMGS=($(jq --raw-output '.images[] | .id'						image.${ID_MBID}.json))
#>>>		declare FRNT=($(jq --raw-output '.images[] | select(.types[]? | contains("Front")) | .id'	image.${ID_MBID}.json))
#>>>		declare BACK=($(jq --raw-output '.images[] | select(.types[]? | contains("Back")) | .id'	image.${ID_MBID}.json))
#>>>		declare MEDI=($(jq --raw-output '.images[] | select(.types[]? | contains("Medium")) | .id'	image.${ID_MBID}.json))
		for FILE in ${IMGS[@]}; do
			if [[ ! -s image.${ID_MBID}.${FILE}.jpg ]]; then
				run_cmd "${FUNCNAME}: images" go_fetch "image.${ID_MBID}.${FILE}.jpg" http://coverartarchive.org/release/${ID_MBID}/${FILE}.jpg || return 1
			fi
		done
		touch _image.${ID_MBID}.${DATE}
	fi
	if { {
		[[ ${ID_COGS} != null ]];
	} && {
		{ [[ ! -f $(${LS} _image.${ID_COGS}.[0-9-]* 2>/dev/null | tail -n1) ]] ||
		[[ ! -s image.${ID_COGS}.html ]]; } && [[ ! -f image.${ID_COGS}.html.null ]];
	}; }; then
		run_cmd "${FUNCNAME}: images"
		if [[ ${ID_COGS//[0-9]} == m ]]; then	run_cmd "${FUNCNAME}: images" go_fetch "image.${ID_COGS}.html" "https://www.discogs.com/master/${ID_COGS/#m}/images" || return 1
		else					run_cmd "${FUNCNAME}: images" go_fetch "image.${ID_COGS}.html" "https://www.discogs.com/release/${ID_COGS}/images" || return 1
		fi
		strip_file image.${ID_COGS}.html
		if {
			{ [[ ! -s image.${ID_COGS}.html ]] && [[ ! -f image.${ID_COGS}.html.null ]]; };
		}; then
			${LL} image.${ID_COGS}.html*
			return 1
		fi
		declare IMGS=($(${SED} \
				-e "s| \"(https://img.discogs.com/[^\"]+)|\n\1\n|g" \
				-e "s|src=\"(https://img.discogs.com/[^\"]+)|\n\1\n|g" \
				-e "s|content=\"(https://img.discogs.com/[^\"]+)|\n\1\n|g" \
				image.${ID_COGS}.html |
			${GREP} "^https://img.discogs.com/" |
			${GREP} "quality\(90\)" |
			${GREP} "format\(jpeg\)" |
			sort -u
		))
		declare IMG=
		for FILE in ${IMGS[@]}; do
			IMG="$(echo "${FILE}" | ${SED} \
				-e "s|.jpe?g.jpg$||g" \
				-e "s|^.+R-||g" \
				-e "s|-|.|g" \
			)"
			if [[ ! -s image.${IMG}.jpg ]]; then
				run_cmd "${FUNCNAME}: images" go_fetch "image.${IMG}.jpg" "${FILE}" || return 1
			fi
		done
		touch _image.${ID_COGS}.${DATE}
	fi
	if {
		[[ ! -s _image.icon.png		]] ||
		{ [[ ! -s _image.front.jpg	]] || [[ $(basename $(realpath _image.front.jpg))	!= $(basename $(realpath ${ID_FCVR})) ]]; } ||
		{ [[ ! -s _image.back.jpg	]] || [[ $(basename $(realpath _image.back.jpg))	!= $(basename $(realpath ${ID_BCVR})) ]]; } ||
		{ [[ ! -s _image.media.jpg	]] || [[ $(basename $(realpath _image.media.jpg))	!= $(basename $(realpath ${ID_MCVR})) ]]; };
	}; then
		run_cmd "${FUNCNAME}: images"
		function image_select {
			declare IMG="${1}" && shift
			declare CVR="${1}" && shift
			declare VAL="${1}" && shift
			echo -en "\n"
			if [[ -s _image.${IMG}.jpg ]]; then
				echo -en "IMAGE (${IMG}): $(basename $(realpath _image.${IMG}.jpg)) (file)\n"
			fi
			if [[ -n ${VAL} ]]; then
				echo -en "IMAGE (${IMG}): ${VAL}\n"
			fi
			if [[ -s ${VAL} ]]; then
				if [[ $(basename $(realpath _image.${IMG}.jpg)) != ${VAL} ]]; then
					${LN} ${VAL} _image.${IMG}.jpg
				fi
			else
				read -p "IMAGE (${IMG})> " FILE
				if [[ -s ${FILE} ]]; then
					${LN} ${FILE} _image.${IMG}.jpg
					meta_set ${CVR} ${FILE}
				fi
			fi
			return 0
		}
		{
			echo -en "\${IMAGE_CMD}: ${IMAGE_CMD}\n"
			${IMAGE_CMD} image.*.{png,jpg} &
			sleep 0.1; jobs 1 2>/dev/null || return 1
			sleep 0.1; jobs 1 2>/dev/null || return 1
		}
		${LS} image.*.{png,jpg} 2>/dev/null | while read -r FILE; do
			echo -en "${FILE}\n"
		done
		echo -en "_image.front.jpg\n"
		image_select front	FCVR ${ID_FCVR}; ID_FCVR="$(meta_get FCVR)"
		image_select back	BCVR ${ID_BCVR}; ID_BCVR="$(meta_get BCVR)"
		image_select media	MCVR ${ID_MCVR}; ID_MCVR="$(meta_get MCVR)"
		echo -en "\n"
		if {
			[[ ! -s _image.front.jpg	]] ||
			[[ ! -s _image.back.jpg		]] ||
			[[ ! -s _image.media.jpg	]];
		}; then
			${LL} _image.*
			return 1
		fi
		if ! convert -verbose -background black -resize 32x32 -extent 32x32 _image.front.jpg _image.icon.png; then
			return 1
		fi
		sleep 1;
		${IMAGE_CMD} _image.*.{png,jpg} 2>/dev/null || return 1
	fi
#>>>	run_cmd "${FUNCNAME}: output" ${LL} _image.*

	ID_NAME="$(meta_get NAME)"
	if {
		[[ -z $(meta_get TITL) ]] ||
		[[ -z $(meta_get ARTS) ]] ||
		[[ -z $(meta_get YEAR) ]] ||
		[[ -z $(meta_get TRCK) ]];
	}; then
		run_cmd "${FUNCNAME}: metadata"
		declare TITL="$(jq --raw-output '.title'			id.${ID_MBID}.json)"
		declare YEAR="$(jq --raw-output '.date'				id.${ID_MBID}.json | ${SED} "s|^([^-]+).*$|\1|g")"
		declare TRCK="$(jq --raw-output '.media[].tracks[] | .position'	id.${ID_MBID}.json | sort -n | tail -n1)"
		declare INDX="$(meta_get INDX)"
		if [[ -z ${TRCK} ]]; then
			TRCK="01"
		fi
		if [[ ${TRCK} == [0-9] ]]; then
			TRCK="0${TRCK}"
		fi
		declare -a TTL
		declare -a ART
		FILE="1"
		while (( ${FILE} <= ${TRCK} )); do
			TTL[${FILE}]="$(jq --raw-output '.media[].tracks[] | select(.position == '${FILE}') | .title'			id.${ID_MBID}.json)"
			ART[${FILE}]="$(jq --raw-output '.media[].tracks[] | select(.position == '${FILE}') | ."artist-credit"[].name'	id.${ID_MBID}.json |
				tr '\n' '^' |
				${SED} "s|\^|${FLAC_ADIV}|g" |
				${SED} "s|${FLAC_ADIV}$||g"
			)"
			if [[ ${FILE} == 1 ]]; then
				ARTS="${ART[${FILE}]}"
			else
				if [[ ${ARTS} != ${ART[${FILE}]} ]]; then
					ARTS="${FLAC_MANY}"
				fi
			fi
			FILE="$(expr ${FILE} + 1)"
		done
		echo -en "TITL: ${TITL}\n"				| tee -a .metadata
		echo -en "ARTS: ${ARTS}\n"				| tee -a .metadata
		echo -en "YEAR: ${YEAR}\n"				| tee -a .metadata
		echo -en "TRCK: ${TRCK}\n"				| tee -a .metadata
		echo -en "INDX: ${INDX}\n"				| tee -a .metadata
		FILE="1"
		while (( ${FILE} <= ${TRCK} )); do
			if [[ ${FILE} == [0-9] ]]; then
				FILE="0${FILE}"
			fi
			echo -en "${FILE}_T: ${TTL[${FILE/#0}]}\n"	| tee -a .metadata
			echo -en "${FILE}_A: ${ART[${FILE/#0}]}\n"	| tee -a .metadata
			FILE="$(expr ${FILE} + 1)"
		done
	fi
	if [[ -z ${ID_NAME} ]]; then
		run_cmd "${FUNCNAME}: metadata"
		ID_NAME="$(namer "$(meta_get ARTS).$(meta_get TITL).$(meta_get YEAR)")"
		ID_NAME="$(echo "${ID_NAME}" | ${SED} "s|^$(namer "${FLAC_MANY}")\.||g")"
		meta_set NAME ${ID_NAME}
	fi
	if [[ ! -f _metadata ]]; then
		run_cmd "${FUNCNAME}: metadata"
		${EDITOR} .metadata
	fi
	if {
		declare FAIL="false"
		if ${GREP} "${FILEALL_CHARS/#[/[^}" .metadata; then FAIL="true"; fi
		if { [[ -z $(meta_get NAME) ]] || [[ -z $(meta_get NAME | ${GREP} -o "^${ID_NAME_CHARS}$") ]]; }; then echo -en "NAME: "; meta_get NAME; FAIL="true"; fi
		if { [[ -z $(meta_get TITL) ]] || [[ -z $(meta_get TITL | ${GREP} -o "^${ID_TITL_CHARS}$") ]]; }; then echo -en "TITL: "; meta_get TITL; FAIL="true"; fi
		if { [[ -z $(meta_get ARTS) ]] || [[ -z $(meta_get ARTS | ${GREP} -o "^${ID_ARTS_CHARS}$") ]]; }; then echo -en "ARTS: "; meta_get ARTS; FAIL="true"; fi
		if { [[ -z $(meta_get YEAR) ]] || [[ -z $(meta_get YEAR | ${GREP} -o "^${ID_YEAR_CHARS}$") ]]; }; then echo -en "YEAR: "; meta_get YEAR; FAIL="true"; fi
		if { [[ -z $(meta_get TRCK) ]] || [[ -z $(meta_get TRCK | ${GREP} -o "^${ID_TRCK_CHARS}$") ]]; }; then echo -en "TRCK: "; meta_get TRCK; FAIL="true"; fi
		FILE="1"
		while (( ${FILE} <= $(meta_get TRCK | ${SED} "s|^0||g") )); do
			if [[ ${FILE} == [0-9] ]]; then
				FILE="0${FILE}"
			fi
			if {
				{ [[ -z $(meta_get ${FILE}_T) ]] || [[ -z $(meta_get ${FILE}_T | ${GREP} -o "^${ID_TITL_CHARS}$") ]]; } ||
				{ [[ -z $(meta_get ${FILE}_A) ]] || [[ -z $(meta_get ${FILE}_A | ${GREP} -o "^${ID_ARTS_CHARS}$") ]]; };
			}; then
				echo -en "${FILE}_T: "; meta_get ${FILE}_T
				echo -en "${FILE}_A: "; meta_get ${FILE}_A
				FAIL="true"
			fi
			FILE="$(expr ${FILE} + 1)"
		done
		${FAIL}
	}; then
		return 1
	fi
	ID_NAME="$(meta_get NAME)"

	if {
		[[ ! -f _metadata ]] ||
		[[ -n $(find .metadata -newer _metadata 2>/dev/null) ]];
	}; then
		run_cmd "${FUNCNAME}: metadata"
		${RSYNC_U} --checksum audio.cue _metadata
		${SED} -i \
			-e "/^REM/d" \
			-e "s|^(CATALOG)|$(
				echo -en "TITLE \\\"$(meta_get TITL)\\\"\\\n"
				echo -en "PERFORMER \\\"$(meta_get ARTS)\\\"\\\n"
				echo -en "REM $(meta_get YEAR)\\\n"
			)\1|g" \
			_metadata
		FILE="1"
		while (( ${FILE} <= $(meta_get TRCK | ${SED} "s|^0||g") )); do
			if [[ ${FILE} == [0-9] ]]; then
				FILE="0${FILE}"
			fi
			${SED} -i "s|^(  TRACK ${FILE} AUDIO)$|\1$(
				echo -en "\\\n    TITLE \"$(meta_get ${FILE}_T | ${SED} "s|([${ID_ESCP_CHARS}])|\\\\\1|g")\""
				echo -en "\\\n    PERFORMER \"$(meta_get ${FILE}_A | ${SED} "s|([${ID_ESCP_CHARS}])|\\\\\1|g")\""
			)|g" \
			_metadata
			FILE="$(expr ${FILE} + 1)"
		done
		touch -r .metadata _metadata
	fi
	if {
		[[ ! -f _metadata.tags ]] ||
		[[ -n $(find .metadata -newer _metadata.tags 2>/dev/null) ]];
	}; then
		run_cmd "${FUNCNAME}: metadata"
		cat /dev/null									>_metadata.tags
		echo -en "VERSION=${DATE}"							>>_metadata.tags
		[[ ${DATE} != $(cat .exported) ]] && echo -en " ($(cat .exported))"		>>_metadata.tags
		echo -en "\n"									>>_metadata.tags
		echo -en "TITLE=$(meta_get ARTS)${FLAC_TDIV//\\}$(meta_get TITL)\n"		>>_metadata.tags
		echo -en "ALBUM=$(meta_get TITL)\n"						>>_metadata.tags
		echo -en "ARTIST=$(meta_get ARTS)\n"						>>_metadata.tags
		echo -en "DATE=$(meta_get YEAR)\n"						>>_metadata.tags
		function do_index {
			if [[ ${1} == [0-9][0-9] ]]; then
				echo -en "0${1}"
			elif [[ ${1} == [0-9] ]]; then
				echo -en "00${1}"
			else
				echo -en "${1}"
			fi
			return 0
		}
		declare TRCK="$(meta_get TRCK | ${SED} "s|^0||g")"
		declare IDXN="1"
		FILE="1"
		# magic numbers!
		while {
			(( ${IDXN} <= 999 )) &&
			(( ${FILE} <= 100 ));	# 99 +1
		}; do
			IDXN="$(do_index ${IDXN})"
			if [[ ${FILE} == [0-9] ]]; then
				FILE="0${FILE}"
			fi
			declare IDX=
			for IDX in $(meta_get INDX | tr ' ' '\n' | ${GREP} "^${FILE}/([0-9]{2}:[0-9]{2})/(.+)$"); do
				declare MRK="$(echo "${IDX}" | ${SED} "s|^${FILE}/([0-9]{2}:[0-9]{2})/(.+)$|\1|g")"
				declare NAM="$(echo "${IDX}" | ${SED} "s|^${FILE}/([0-9]{2}:[0-9]{2})/(.+)$|\2|g")"
				NAM="${NAM//${FLAC_ISEP}/ }"
				echo -en "CHAPTER${IDXN}=00:${MRK}.000\n"			>>_metadata.tags
				echo -en "CHAPTER${IDXN}NAME=${FLAC_INDX}${NAM}\n"		>>_metadata.tags
				IDXN="$(expr ${IDXN} + 1)"
				IDXN="$(do_index ${IDXN})"
			done
			if (( ${FILE/#0} > ${TRCK} )); then
				FILE="$(expr ${FILE} + 1)"
				continue
			fi
			declare MRK="$(
				${GREP} -A2 "^  TRACK ${FILE} AUDIO$" audio.cue |
				${SED} -n "s|^    INDEX 01 ([0-9]{2}:[0-9]{2}):[0-9]{2}$|\1|gp"
			)"
			for IDX in $(meta_get INDX | tr ' ' '\n' | ${GREP} "^${FILE}/([0-9]{2}:[0-9]{2})$"); do
				MRK="$(echo "${IDX}" | ${SED} "s|^${FILE}/([0-9]{2}:[0-9]{2})$|\1|g")"
			done
			echo -en "CHAPTER${IDXN}=00:${MRK}.000\n"				>>_metadata.tags
			echo -en "CHAPTER${IDXN}NAME="						>>_metadata.tags
			echo -en "${FILE}${FLAC_NDIV//\\}"					>>_metadata.tags
			echo -en "$(meta_get ${FILE}_T)${FLAC_TDIV//\\}$(meta_get ${FILE}_A)"	>>_metadata.tags
			echo -en "\n"								>>_metadata.tags
			IDXN="$(expr ${IDXN} + 1)"
			FILE="$(expr ${FILE} + 1)"
		done
		if [[ $(meta_get ARTS) == ${FLAC_MANY} ]]; then
			${SED} -i "s|^(TITLE=)${FLAC_MANY}${FLAC_TDIV}|\1|g"			_metadata.tags
		else
			${SED} -i "s|^(CHAPTER.+)${FLAC_TDIV}.+$|\1|g"				_metadata.tags
		fi
		touch -r .metadata _metadata.tags
	fi
	run_cmd "${FUNCNAME}: output" cueprint --input-format cue _metadata
	run_cmd "${FUNCNAME}: output" cat _metadata
	run_cmd "${FUNCNAME}: output" cat _metadata.tags

	run_cmd "${FUNCNAME}: encode"
	declare TAGS="$(
		cat _metadata.tags | while read -r FILE; do
			echo "--tag=\"${FILE}\""
		done
	)"
	if [[ ! -s ${ID_NAME}.flac ]]; then
		eval run_cmd "\"${FUNCNAME}: encode\"" flac \
			${FLAC_OPTS} \
			\
			--tag-from-file="\"METADATA=.metadata\"" \
			--tag-from-file="\"METAFILE=_metadata\"" \
			--cuesheet="\"_metadata\"" \
			${TAGS} \
			\
			--picture="\"1||||_image.icon.png\"" \
			--picture="\"3||||_image.front.jpg\"" \
			--picture="\"4||||_image.back.jpg\"" \
			--picture="\"6||||_image.media.jpg\"" \
			\
			"${@}" \
			--output-name="\"${ID_NAME}.flac\"" \
			audio.wav \
			|| return 1
	fi
	if [[ -f ${ID_NAME}.flac ]]; then
		if [[ ! -s ${ID_NAME}.wav ]]; then
#>>>			run_cmd "${FUNCNAME}: verify"	flac --force --analyze	${ID_NAME}.flac || return 1
#>>>			run_cmd "${FUNCNAME}: verify"	flac --force --test	${ID_NAME}.flac || return 1
			run_cmd "${FUNCNAME}: verify"	flac --force --decode	${ID_NAME}.flac || return 1
			if ! run_cmd "${FUNCNAME}: verify" diff ${DIFF_OPTS} ${ID_NAME}.wav audio.wav; then
				return 1
			fi
		fi
		run_cmd "${FUNCNAME}: info" ffmpeg -i				${ID_NAME}.flac #>>> || return 1
		run_cmd "${FUNCNAME}: info" metaflac --list			${ID_NAME}.flac | ${GREP} -A4 "^METADATA" | ${GREP} -v "^--$" #>>> || return 1
		run_cmd "${FUNCNAME}: info" metaflac --export-tags-to=-		${ID_NAME}.flac || return 1
		run_cmd "${FUNCNAME}: info" metaflac --export-cuesheet-to=-	${ID_NAME}.flac || return 1
	fi

	run_cmd "${FUNCNAME}: archive"
	if [[ ! -s ${ID_NAME}.tar.xz ]]; then
		function tarfiles {
			find ./ -maxdepth 1 ! -type d | ${SED} "s|^\./||g" | sort
		}
		run_cmd "${FUNCNAME}: archive" ${FLAC_HASH} $(tarfiles) \
			| ${GREP} -v \
				-e " _checksum" \
				-e " audio_" \
				-e " ${ID_NAME//+/\\+}" \
			| tee _checksum
			[[ ${PIPESTATUS[0]} != 0 ]] && return 1
		run_cmd "${FUNCNAME}: archive" tar --xz -cvv \
			--exclude="audio.*" \
			--exclude="audio_*" \
			--exclude="${ID_NAME}*" \
			-f ${ID_NAME}.tar.xz $(tarfiles) \
			|| return 1
	fi
	while [[ -n $(metaflac --list --block-type="PICTURE" --block-number="$((${FLAC_BLCK}+1))" ${ID_NAME}.flac 2>/dev/null) ]]; do
		run_cmd "${FUNCNAME}: archive" metaflac \
			--block-type="PICTURE" \
			--block-number="$((${FLAC_BLCK}+1))" \
			--remove \
			${ID_NAME}.flac \
			|| return 1
	done

	run_cmd "${FUNCNAME}: embed"
	declare TGZ_LST="$(metaflac --list --block-type="PICTURE" --block-number="${FLAC_BLCK}" ${ID_NAME}.flac 2>/dev/null | ${SED} -n "s|^ +description: ||gp")"
	declare TGZ_OUT="$(metaflac --block-number="${FLAC_BLCK}" --export-picture-to=- ${ID_NAME}.flac 2>/dev/null | ${FLAC_HASH} | ${GREP} -o "^${FLAC_HASH_CHARS}")"
	declare TGZ_FIL="$(${FLAC_HASH} ${ID_NAME}.tar.xz | ${GREP} -o "^${FLAC_HASH_CHARS}")"
	if {
		[[ ${TGZ_LST} != ${TGZ_OUT} ]] ||
		[[ ${TGZ_LST} != ${TGZ_FIL} ]];
	}; then
		if [[ -n $(metaflac --list --block-type="PICTURE" --block-number="${FLAC_BLCK}" ${ID_NAME}.flac 2>/dev/null) ]]; then
			run_cmd "${FUNCNAME}: archive" metaflac \
				--block-type="PICTURE" \
				--block-number="${FLAC_BLCK}" \
				--remove \
				${ID_NAME}.flac \
				|| return 1
		fi
		run_cmd "${FUNCNAME}: archive" metaflac \
			--import-picture-from="0|image/png|$(${FLAC_HASH} ${ID_NAME}.tar.xz | ${GREP} -o "^${FLAC_HASH_CHARS}")|32x32x32|${ID_NAME}.tar.xz" \
			${ID_NAME}.flac \
			|| return 1
	fi

	run_cmd "${FUNCNAME}: validate"
	if [[ ! -d ${ID_NAME}.flac.dir ]]; then
		flac_unpack ${ID_NAME}.flac
		if {
			! run_cmd "${FUNCNAME}: validate" diff ${DIFF_OPTS} -r \
				--exclude="audio_*" \
				--exclude="${ID_NAME}*" \
				${PWD} ${ID_NAME}.flac.dir;
		}; then
			return 1
		fi
	fi

	run_cmd "${FUNCNAME}: complete"
	run_cmd "${FUNCNAME}: output" metaflac \
		--block-number="${FLAC_BLCK}" \
		--export-picture-to=- \
		${ID_NAME}.flac \
		| tar --xz -tvv -f -
#>>>	run_cmd "${FUNCNAME}: output" ${LL}
	run_cmd "${FUNCNAME}: output" ${LL} $(find ./ -maxdepth 1 -empty | ${SED} "s|^\./||g" | sort)
	run_cmd "${FUNCNAME}: output" ${DU} -cms ${ID_NAME}*
	return 0
}

################################################################################

function flac_unpack {
	declare UNPACK="${1}" && shift
	declare ADDARG=
	if [[ ${1} != +([0-9]) ]]; then
		ADDARG="${1}"
		shift
	fi
	declare TGZ_LST="$(metaflac --list --block-type="PICTURE" --block-number="${FLAC_BLCK}" ${UNPACK} 2>/dev/null | ${SED} -n "s|^ +description: ||gp")"
	declare TGZ_OUT="$(metaflac --block-number="${FLAC_BLCK}" --export-picture-to=- ${UNPACK} 2>/dev/null | ${FLAC_HASH} | ${GREP} -o "^${FLAC_HASH_CHARS}")"
	if {
		[[ -n ${TGZ_LST} ]] &&
		[[ ${TGZ_LST} != ${TGZ_OUT} ]];
	}; then
		echo -en "${TGZ_LST}\n"
		echo -en "${TGZ_OUT}\n"
		return 1
	fi
	run_cmd "${FUNCNAME}" metaflac --list			${UNPACK} | ${GREP} -A4 "^METADATA" | ${GREP} -v "^--$" #>>> || return 1
	run_cmd "${FUNCNAME}" metaflac --export-tags-to=-	${UNPACK} || return 1
	if [[ ${ADDARG} == -l ]]; then
		run_cmd "${FUNCNAME}" metaflac \
			--block-number="${FLAC_BLCK}" \
			--export-picture-to=- \
			${UNPACK} \
			| tar --xz -tvv -f -
		return 0
	fi
	if [[ ${ADDARG} == -x ]]; then
		${MKDIR} ${UNPACK}.dir
		run_cmd "${FUNCNAME}" metaflac \
			--block-number="${FLAC_BLCK}" \
			--export-picture-to=- \
			${UNPACK} \
			| (cd ${UNPACK}.dir; tar --xz -xvv .metadata)
		${RSYNC_U} --checksum ${UNPACK}.dir/.metadata ${UNPACK}.metadata
		run_cmd "${FUNCNAME}" cat ${UNPACK}.metadata
		return 0
	fi
	if [[ ! -d ${UNPACK}.dir ]]; then
		${MKDIR} ${UNPACK}.dir
		run_cmd "${FUNCNAME}" metaflac \
			--block-number="${FLAC_BLCK}" \
			--export-picture-to=- \
			${UNPACK} \
			| tar --xz -xvv -C ${UNPACK}.dir -f - \
			|| return 1
		function validate_file {
			declare TAG="${1}" && shift
			declare EXP="${1}" && shift
			run_cmd "${FUNCNAME}" metaflac --export-tags-to=- ${UNPACK} \
				| ${SED} -n "/^${TAG}=/,/^$/p" \
				| ${SED} -e "s|^${TAG}=||g" -e "/^$/d" \
				>${UNPACK}.dir/+${FUNCNAME}.${TAG}
				[[ ${PIPESTATUS[0]} != 0 ]] && return 1
			if [[ -s ${UNPACK}.dir/+${FUNCNAME}.${TAG} ]]; then
				(cd ${UNPACK}.dir && run_cmd "${FUNCNAME}" diff ${DIFF_OPTS} +${FUNCNAME}.${TAG} ${EXP}) || return 1
			fi
			${RM} ${UNPACK}.dir/+${FUNCNAME}.${TAG}
			return 0
		}
		validate_file METADATA .metadata							|| return 1
		validate_file METAFILE _metadata							|| return 1
		run_cmd "${FUNCNAME}" metaflac --export-cuesheet-to=${UNPACK}.dir/audio.cue		${UNPACK}		|| return 1
		${SED} -i -e "/^REM/d" -e "s|^(FILE \").+$|\1audio.wav\" WAVE|g"			${UNPACK}.dir/audio.cue	|| return 1
		run_cmd "${FUNCNAME}" flac --force --decode --output-name=${UNPACK}.dir/audio.wav	${UNPACK}		|| return 1
		(cd ${UNPACK}.dir && run_cmd "${FUNCNAME}" ${FLAC_HASH} --check _checksum)		|| return 1
	fi
	declare DESTNAME="$(realpath ${ADDARG} 2>/dev/null)"
	declare BASENAME="$(meta_get ${UNPACK}.dir/.metadata NAME)"
	if [[ ${1} == +([0-9]) ]]; then
		shopt -s lastpipe
		while [[ ${1} == +([0-9]) ]]; do
			FILE="${1}" && shift
			if [[ ${FILE} == [0-9] ]]; then
				FILE="0${FILE}"
			fi
			if [[ ! -s $(${LS} ${UNPACK}.dir/${BASENAME}.${FILE}.* 2>/dev/null) ]]; then
				(cd ${UNPACK}.dir && flac_export audio.wav _metadata ${BASENAME} ${FILE})	|| return 1
			fi
			if [[ -d ${DESTNAME} ]]; then
				${RSYNC_U} ${UNPACK}.dir/${BASENAME}.${FILE}.*.flac ${DESTNAME}/		|| return 1
			fi
		done
	fi
	run_cmd "${FUNCNAME}" ${LL} ${UNPACK}.dir
	if [[ -d ${DESTNAME} ]]; then
		(cd ${DESTNAME} && run_cmd "${FUNCNAME}" ${LL} ${BASENAME}.*.flac)
	fi
	return 0
}

########################################

function flac_export {
	declare INPUTF="${1}" && shift
	declare CUEDAT="${1}" && shift
	declare PREFIX="${INPUTF/%.wav}"
	declare TRACKR="[0-9][0-9]"
	declare COUNTR="0"
	if {
		[[ -n ${1} ]] &&
		[[ ${1} != +([0-9]) ]] &&
		[[ ${1} != -+(*) ]];
	}; then
		PREFIX="$(basename ${1})"
		shift
	fi
	if {
		[[ ${1} == +([0-9]) ]] &&
		[[ ${1} != +(0) ]];
	}; then
		TRACKR="${1}"
		shift
		if [[ ${TRACKR} == [0-9] ]]; then
			TRACKR="0${TRACKR}"
		fi
		COUNTR="${TRACKR}"
	fi
	if {
		[[ ${COUNTR} != +(0) ]] &&
		[[ -n $(
			${GREP} -A4 "^  TRACK 01 AUDIO$" ${CUEDAT} |
			${GREP} "^    INDEX 00 00:00:00$" ${CUEDAT}
		) ]];
	}; then
		COUNTR="$(expr ${COUNTR} + 1)"
	fi
	eval run_cmd "${FUNCNAME}" shnsplit \
		-D \
		-O always \
		-i wav \
		-f ${CUEDAT} \
		-a "\"${PREFIX}.\"" \
		-n "\"%02d\"" \
		-t "\"%n.%t\"" \
		$(if [[ ${COUNTR} != +(0) ]]; then
			echo -en "-x ${COUNTR}"
		fi) \
		-o \"flac flac \
			${FLAC_OPTS} \
			--output-name %f \
			- \
		\" \
		${INPUTF} \
		|| return 1
	declare DONAME=
	${LS} ${PREFIX}.${TRACKR}.* 2>/dev/null | while read -r FILE; do
		DONAME="$(namer ${FILE})"
		if [[ "${FILE}" != "${DONAME}" ]]; then
			${MV} "${FILE}" "${DONAME}" || return 1
		fi
	done
	${LS} ${PREFIX}.${TRACKR}.* 2>/dev/null | while read -r FILE; do
		DONAME="$(echo "${FILE}" | ${SED} "s|^${PREFIX//+/\\+}.([0-9]{2}).+$|\1|g")"
		cat /dev/null						>_metadata.${DONAME}
		echo -en "VERSION=${DATE}${FLAC_TDIV//\\}"		>>_metadata.${DONAME}
		${SED} -n "s|^VERSION=(.+)$|\1|gp" _metadata.tags	>>_metadata.${DONAME}
		echo -en "ALBUM=$(meta_get TITL)\n"			>>_metadata.${DONAME}
		echo -en "DATE=$(meta_get YEAR)\n"			>>_metadata.${DONAME}
		echo -en "TRACKNUMBER=${DONAME}\n"			>>_metadata.${DONAME}
		echo -en "TITLE=$(meta_get ${DONAME}_T)\n"		>>_metadata.${DONAME}
		echo -en "ARTIST=$(meta_get ${DONAME}_A)\n"		>>_metadata.${DONAME}
		run_cmd "${FUNCNAME}" metaflac \
			--import-tags-from="_metadata.${DONAME}" \
			--import-picture-from="1||||_image.icon.png" \
			--import-picture-from="3||||_image.front.jpg" \
			${FILE} \
			|| return 1
		run_cmd "${FUNCNAME}: info" metaflac --list		${FILE} | ${GREP} -A4 "^METADATA" | ${GREP} -v "^--$" #>>> || return 1
		run_cmd "${FUNCNAME}: info" metaflac --export-tags-to=-	${FILE} || return 1
	done
	return 0
}

########################################

function flac_playlist {
	declare PLAYLST="${1}" && shift
	declare PLAYDIR="$(dirname ${PLAYLST})"
	declare PLAYFIL="$(basename ${PLAYLST})"
	declare SEARCH="^([^#].+)[.]([0-9]{2})[.].+$"
	${GREP} "${SEARCH}" ${PLAYLST} |
		while read -r FILE; do
			if [[ ! -s ${PLAYDIR}/${FILE} ]]; then
				FILE="$(echo "${FILE}" | ${SED} -n "s|${SEARCH}|\1.flac ${PLAYDIR} \2|gp")"
				${_SELF} ${FILE} || return 1
			fi
		done
	run_cmd "${FUNCNAME}" ${LL} ${PLAYDIR}
	run_cmd "${FUNCNAME}" ${GREP} -v "${SEARCH}" ${PLAYLST} | ${SED} "/^$/d"
	divider
	(cd ${PLAYDIR} && ${GREP} "${SEARCH}" ${PLAYLST} |
		while read -r FILE; do
			if [[ ! -s ${FILE} ]]; then
				${GREP} "^${FILE//+/\\+}$" ${PLAYLST}
			fi
		done
	)
	divider
	(cd ${PLAYDIR} && ${LS} -A | ${GREP} -v "^${PLAYFIL}$" |
		while read -r FILE; do
			if [[ -z $(${GREP} "^${FILE//+/\\+}$" ${PLAYLST}) ]]; then
				${LL} ${FILE}
			fi
		done
	)
	divider
	wc -l ${PLAYLST}
	${LS} -A ${PLAYDIR} | wc -l
	return 0
}

########################################

function flac_list {
#>>>
#	${LS} -A "${@}" |
#		${SED} -n "s|^([^.]+)[.](([^.]+)[.])?([^.]+)[.]flac|\4 \1 \3|gp" |
#		sort |
#		while read -r FILE
#	do
#		#           5     + 45     + 30			= 80
#		printf "%-4.4s %-44.44s %-30.30s\n"		${FILE//^^^/ }
#	done
#	echo -en "\n"
#>>>
	declare -a FILES
	${LS} -A "${@}" | ${GREP} "[.]flac$" | while read -r FILE; do
		FILE="$(
			metaflac --export-tags-to=- ${FILE} 2>&1 |
			tr '\n' '|' |
			${SED} "s|^.*ALBUM=([^|]+).*ARTIST=([^|]+).*DATE=([^|]+).*$|\3\|\1\|\2\|${FILE}|g"
		)"
		IFS=$'\n' FILES=($(echo -en "${FILE//|/\\n}")); unset IFS
		#           5     + 25     + 20     + 30	= 80
		printf "%-4.4s %-24.24s %-19.19s %-30.30s\n"	"${FILES[0]}" "${FILES[1]}" "${FILES[2]}" "${FILES[3]}"
		#           5     + 45     + 30			= 80
#>>>		printf "%-4.4s %-44.44s %-30.30s\n"		"${FILES[0]}" "${FILES[1]}" "${FILES[2]}"
	done |
		sort
	return 0
}

########################################

function flac_metadata {
	if [[ ${1} == -l ]]; then
		shift
		for FILE in *.flac; do
			${_SELF} ${FILE} -l 2>&1
		done |
			${GREP} -B1 -A30 "export-picture-to" |
			${PAGER} +/export-picture-to
	else
		${MKDIR} .metadata
		for FILE in *.flac; do
			${_SELF} ${FILE} -x || return 1
			${RSYNC_U} --checksum ${FILE}.metadata .metadata/${FILE/%.flac}.metadata || return 1
			${RM} ${FILE}.dir ${FILE}.metadata
		done
		${LL} .metadata
	fi
	return 0
}

########################################

function flac_rebuild {
	if [[ ${1} == -m ]]; then
		shift
		for FILE in "${@}"; do
			touch -r ${FILE} ${FILE}.touch
		done
		${EDITOR} "${@}"
		for FILE in "${@}"; do
			touch -r ${FILE}.touch ${FILE}
			${RM} ${FILE}.touch
		done
		return 0
	fi
	declare AUTO="false"
	if [[ ${1} == -a ]]; then
		AUTO="true"
		shift
	fi
	for FILE in "${@}"; do
		[[ -z $(file ${FILE} | ${GREP} "FLAC") ]] && continue
		${_SELF} ${FILE}											|| return 1
		${RSYNC_U} --checksum ${FILE} ${FILE}.dir/${FILE}							|| return 1
		${_SELF} ${FILE}.dir/${FILE}										|| return 1
		${RSYNC_U} --checksum .metadata/${FILE/%.flac}.metadata ${FILE}.dir/${FILE}.dir/.metadata		|| return 1
		${RM} ${FILE}.dir/${FILE}.dir/_metadata*								|| return 1
		if ${AUTO}; then
			(cd ${FILE}.dir/${FILE}.dir && EDITOR="cat" DATE="$(cat .exported)" ${_SELF} -c)		|| return 1
			diff ${DIFF_OPTS} ${FILE}.dir ${FILE}.dir/${FILE}.dir >${FILE}.diff 2>&1
		else
			(cd ${FILE}.dir/${FILE}.dir && EDITOR="cat" DATE="$(cat .exported)" PROMPT="simple" ${SHELL})	|| return 1
			vdiff -r ${FILE}.dir ${FILE}.dir/${FILE}.dir
			read -p "CONTINUE"
		fi
		touch -r ${FILE} ${FILE}.dir/${FILE}.dir/${FILE}							|| return 1
		${RSYNC_U} --checksum ${FILE}.dir/${FILE}.dir/${FILE} ${FILE}						|| return 1
		${RM} ${FILE}.dir											|| return 1
		${AUTO} && { ${_SELF} ${FILE}										|| return 1; }
	done
	return 0
}

################################################################################

  if { [[ -s ${SOURCE} ]] && [[ -n $(file ${SOURCE} | ${GREP} "FLAC") ]]; }; then	flac_unpack	"${SOURCE}" "${@}" || exit 1
elif { [[ -s ${SOURCE} ]] && [[ ${SOURCE/%.m3u} != ${SOURCE} ]]; }; then		flac_playlist	"${SOURCE}" "${@}" || exit 1
elif [[ ${RTYPE} == -l ]]; then		flac_list	"${@}" || exit 1
elif [[ ${RTYPE} == -y ]]; then		flac_metadata	"${@}" || exit 1
elif [[ ${RTYPE} == -r ]]; then		flac_rebuild	"${@}" || exit 1
elif [[ ${RTYPE} == -d ]]; then		dvd_rescue	"${@}" || exit 1
elif [[ ${RTYPE} == -v ]]; then		vlc_encode	"${@}" || exit 1
elif [[ ${RTYPE} == -m ]]; then		mp_encode	"${@}" || exit 1
elif [[ ${RTYPE} == -a ]]; then		cd_export	"${@}" || exit 1
elif [[ ${RTYPE} == -t ]]; then		cd_cuefile	"${@}" || exit 1
elif [[ ${RTYPE} == -c ]]; then		cd_encode	"${@}" || exit 1
fi

exit 0
################################################################################
# end of file
################################################################################
