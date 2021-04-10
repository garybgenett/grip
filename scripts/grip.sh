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

declare DATE="$(date --iso)"

declare FRAMES_PER_SECOND="75"
declare SECOND_PER_MINUTE="60"

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

declare FLAC_MANY="Various Artists"
declare FLAC_TDIV=" \/\/ "
declare FLAC_ADIV="\; "
declare FLAC_NDIV="\. "

declare FLAC_HASH_CHARS="[0-9a-f]{40}"
declare FLAC_HASH="sha1sum"
declare FLAC_BLCK="8"

declare ID_DISC_CHARS="[a-zA-Z0-9_.-]{28}"
declare ID_DISC=
declare ID_CODE_CHARS="[0-9]{13}"
declare ID_CODE=
declare ID_MBID_CHARS="[0-9a-f-]{36}"
declare ID_MBID=

declare ID_URL=
declare ID_URL_NUM=
declare ID_URL_IMG=

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

function strip_file {
	declare STRIP="${1}" && shift
	${SED} "/^[[:space:]]*$/d" ${STRIP} | tr -d '\n' >${STRIP}.${FUNCNAME}
	${MV} ${STRIP}.${FUNCNAME} ${STRIP}
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
		TRACK="$(echo "${FILE}" | ${SED} "s|^[[:space:]]*([0-9]+)\:([0-9]+)\.([0-9]+)[[:space:]]+([0-9]+).*$|\4|g")"; if [[ ${TRACK} != [0-9][0-9] ]]; then TRACK="0${TRACK}"; fi
		IDX_M="$(echo "${FILE}" | ${SED} "s|^[[:space:]]*([0-9]+)\:([0-9]+)\.([0-9]+)[[:space:]]+([0-9]+).*$|\1|g")"; if [[ ${IDX_M} != [0-9][0-9] ]]; then IDX_M="0${IDX_M}"; fi
		IDX_S="$(echo "${FILE}" | ${SED} "s|^[[:space:]]*([0-9]+)\:([0-9]+)\.([0-9]+)[[:space:]]+([0-9]+).*$|\2|g")"; if [[ ${IDX_S} != [0-9][0-9] ]]; then IDX_S="0${IDX_S}"; fi
		IDX_F="$(echo "${FILE}" | ${SED} "s|^[[:space:]]*([0-9]+)\:([0-9]+)\.([0-9]+)[[:space:]]+([0-9]+).*$|\3|g")"; if [[ ${IDX_F} != [0-9][0-9] ]]; then IDX_F="0${IDX_F}"; fi
		echo -en "  TRACK ${TRACK} AUDIO\n"
		echo -en "    INDEX 01 ${TTL_M}:${TTL_S}:${TTL_F}\n"
		echo -en "           + ${IDX_M}:${IDX_S}:${IDX_F}\n" 1>&2
		echo -en "\n" 1>&2
		TTL_F="$(expr ${TTL_F} + ${IDX_F})";	((${TTL_F} >= ${FRAMES_PER_SECOND})) && { TTL_S="$(expr ${TTL_S} + 1)"; TTL_F="$(expr ${TTL_F} - ${FRAMES_PER_SECOND})"; }
		TTL_S="$(expr ${TTL_S} + ${IDX_S})";	((${TTL_S} >= ${SECOND_PER_MINUTE})) && { TTL_M="$(expr ${TTL_M} + 1)"; TTL_S="$(expr ${TTL_S} - ${SECOND_PER_MINUTE})"; }
							((${TTL_S} >= ${SECOND_PER_MINUTE})) && { TTL_M="$(expr ${TTL_M} + 1)"; TTL_S="$(expr ${TTL_S} - ${SECOND_PER_MINUTE})"; }
		TTL_M="$(expr ${TTL_M} + ${IDX_M})";
		if [[ ${TTL_M} != [0-9][0-9] ]]; then TTL_M="0${TTL_M}"; fi
		if [[ ${TTL_S} != [0-9][0-9] ]]; then TTL_S="0${TTL_S}"; fi
		if [[ ${TTL_F} != [0-9][0-9] ]]; then TTL_F="0${TTL_F}"; fi
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
	if [[ ${1} == -s ]]; then
		shift
		declare SAFE_LIST="
			.exported
			.audio.log
			.audio.cue
			audio.cue
			audio.wav
			\
			.id.disc
			.id.code
			_audio.cue
		"
		run_cmd "${FUNCNAME}" ${LL} --directory ${SAFE_LIST}
		run_cmd "${FUNCNAME}" ${LL} --directory $(
			eval find ./ -mindepth 1 -maxdepth 1 $(
				for FILE in ${SAFE_LIST}; do
					echo "\\( -path ./${FILE} -prune \\) -o "
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
		run_cmd "${FUNCNAME}: audio" $(which cdparanoia)	--version	2>&1 | tee -a .audio.log
		run_cmd "${FUNCNAME}: audio" $(which cdda2wav)		--version	2>&1 | tee -a .audio.log
		run_cmd "${FUNCNAME}: audio" $(which cdir)		-V		2>&1 | tee -a .audio.log
		run_cmd "${FUNCNAME}: audio" $(which cdir) \
			-D -n -d ${SOURCE} \
			2>&1 | tee -a .audio.log
			[[ ${PIPESTATUS[0]} != 0 ]] && return 1
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
		run_cmd "${FUNCNAME}: audio"
		${RSYNC_U} audio.cue .audio.cue	|| return 1
		${SED} -i "/^REM/d" audio.cue	|| return 1
		${RSYNC_U} audio.cue _audio.cue	|| return 1
		echo "${DATE}" >.exported
	fi
	if ! run_cmd "${FUNCNAME}: output" diff ${DIFF_OPTS} .audio.cue audio.cue; then
		if ! run_cmd "${FUNCNAME}: output" diff ${DIFF_OPTS} _audio.cue audio.cue; then
			return 1
		fi
	elif ${LL} _audio.cue 2>/dev/null; then
		return 1
	fi

	ID_DISC="$(head -n1 .id.disc 2>/dev/null)"
	if [[ -z $(echo "${ID_DISC}" | ${GREP} -o "^${ID_DISC_CHARS}$") ]]; then
		run_cmd "${FUNCNAME}: disc"
		echo -en "$(which cdda2wav) -info-only -device ${SOURCE}\n"
		if [[ -n ${ID_DISC} ]]; then
			echo -en "CDINDEX[${ID_DISC}]\n"
		fi
		read -p "CDINDEX: " ID_DISC
		if [[ -z $(echo "${ID_DISC}" | ${GREP} -o "^${ID_DISC_CHARS}$") ]]; then
			return 1
		fi
		echo "${ID_DISC}" >.id.disc
	fi
	run_cmd "${FUNCNAME}: output" cat .id.disc

	ID_CODE="$(head -n1 .id.code 2>/dev/null)"
	if {
		[[ -z $(echo "${ID_CODE}" | ${GREP} -o "^${ID_CODE_CHARS}$") ]] &&
		[[ ${ID_CODE} != null ]];
	}; then
		run_cmd "${FUNCNAME}: code"
		ID_CODE="$(${SED} -n "s|^CATALOG (.+)$|\1|gp" audio.cue)"
		if [[ -n ${ID_CODE} ]]; then
			echo -en "BARCODE[${ID_CODE}]\n"
		fi
		read -p "BARCODE: " ID_CODE
		if [[ ${ID_CODE} != null ]]; then
			if [[ -z $(echo "${ID_CODE}" | ${GREP} -o "^${ID_CODE_CHARS}$") ]]; then
				return 1
			fi
			if [[ -z $(${GREP} "^CATALOG " audio.cue) ]]; then
				${SED} -i "s|^(FILE .+$)$|CATALOG ${ID_CODE}\n\1|g" audio.cue
				${RSYNC_U} audio.cue _audio.cue || return 1
			fi
		fi
		echo "${ID_CODE}" >.id.code
	fi
	run_cmd "${FUNCNAME}: output" cat .id.code

	ID_URL="$(head -n1 _id.url 2>/dev/null)"
	if {
		[[ -z ${ID_URL} ]] &&
		[[ ${ID_URL} != null ]];
	}; then
		run_cmd "${FUNCNAME}: cogs"
		echo -en "URL: https://www.discogs.com/search/?type=release&q=${ID_CODE}\n"
		read -p "URL: " ID_URL
		if [[ ${ID_URL} != null ]]; then
			if [[ -z ${ID_URL} ]]; then
				return 1
			fi
			ID_URL_NUM="$(echo "${ID_URL}" | ${SED} "s|^.+/([^/]+)$|\1|g")"
			run_cmd "${FUNCNAME}: cogs" ${WGET_C} --output-document="id.${ID_URL_NUM}.html" "${ID_URL}" || return 1
			strip_file id.${ID_URL_NUM}.html
			if [[ ! -s id.${ID_URL_NUM}.html ]]; then
				${LL} id.${ID_URL_NUM}.html*
				return 1
			fi
		fi
		echo "${ID_URL}" >_id.url
	fi
	ID_URL_NUM="$(echo "${ID_URL}" | ${SED} "s|^.+/([^/]+)$|\1|g")"
	run_cmd "${FUNCNAME}: output" cat _id.url

	ID_MBID="$(head -n1 _id.mbid 2>/dev/null)"
	if {
		[[ -z $(echo "${ID_MBID}" | ${GREP} -o "^${ID_MBID_CHARS}$") ]] &&
		[[ ${ID_MBID} != null ]];
	}; then
		run_cmd "${FUNCNAME}: mbid"
		run_cmd "${FUNCNAME}: mbid" ${WGET_C} --output-document="mb.${ID_CODE}.html" "https://musicbrainz.org/search?advanced=1&type=release&query=barcode:${ID_CODE}"	#>>> || return 1
		run_cmd "${FUNCNAME}: mbid" ${WGET_C} --output-document="mb.${ID_DISC}.html" "https://musicbrainz.org/cdtoc/${ID_DISC}"						#>>> || return 1
		strip_file mb.${ID_CODE}.html
		strip_file mb.${ID_DISC}.html
		if {
			{ [[ ! -s mb.${ID_CODE}.html ]] && [[ ! -f mb.${ID_CODE}.html.null ]]; } ||
			{ [[ ! -s mb.${ID_DISC}.html ]] && [[ ! -f mb.${ID_DISC}.html.null ]]; };
		}; then
			${LL} mb.${ID_CODE}.html*
			${LL} mb.${ID_DISC}.html*
			return 1
		fi
		run_cmd "${FUNCNAME}: mbid"
		declare ID_MBIDS=($(
			${SED} "s|(<a href=\"/release/${ID_MBID_CHARS}\")|\n\1|g" mb.${ID_CODE}.html mb.${ID_DISC}.html |
			${SED} -n "s|^.+/release/(${ID_MBID_CHARS}).+>([A-Z]{2})<.+$|\2:\1|gp" |
			sort -u
		))
		echo -en "\n"
		for FILE in ${ID_MBIDS[@]}; do
			echo -en "${FILE/%:*}: https://musicbrainz.org/release/${FILE/#*:}\n"
		done
		if [[ -z $(echo "${ID_MBID}" | ${GREP} -o "^${ID_MBID_CHARS}$") ]]; then
			if [[ -n ${ID_MBID} ]]; then
				echo -en "ID_MBID[${ID_MBID}]\n"
			fi
			read -p "ID_MBID: " ID_MBID
		fi
		ID_MBID="${ID_MBID/#*\/}"
		if [[ ${ID_MBID} != null ]]; then
			if [[ -z $(echo "${ID_MBID}" | ${GREP} -o "^${ID_MBID_CHARS}$") ]]; then
				return 1
			fi
#>>>			run_cmd "${FUNCNAME}: mbid" $(which curl) --verbose --remote-time --output "id.${ID_MBID}.html" "https://musicbrainz.org/release/${ID_MBID}"							|| return 1
			run_cmd "${FUNCNAME}: mbid" ${WGET_C} --output-document="id.${ID_MBID}.html" "https://musicbrainz.org/release/${ID_MBID}"									|| return 1
			run_cmd "${FUNCNAME}: mbid" ${WGET_C} --output-document="id.${ID_MBID}.json" "https://musicbrainz.org/ws/2/release/${ID_MBID}?inc=aliases+artist-credits+labels+discids+recordings&fmt=json"	|| return 1
			strip_file id.${ID_MBID}.html
			strip_file id.${ID_MBID}.json
			if {
				[[ ! -s id.${ID_MBID}.html ]] ||
				[[ ! -s id.${ID_MBID}.json ]];
			}; then
				${LL} id.${ID_MBID}.html*
				${LL} id.${ID_MBID}.json*
				return 1
			fi
		fi
		echo "${ID_MBID}" >_id.mbid
	fi
	run_cmd "${FUNCNAME}: output" cat _id.mbid

	if [[ ! -s _image.icon.png ]]; then
		run_cmd "${FUNCNAME}: images"
		if {
			[[ ! -f $(${LS} _image.${ID_URL_NUM}.[0-9-]*) ]] &&
			[[ ${ID_URL} != null ]];
		}; then
			ID_URL_IMG="$(head -n2 _id.url 2>/dev/null | tail -n1)"
			if {
				[[ -z ${ID_URL_IMG} ]] ||
				[[ $(wc -l _id.url 2>/dev/null | ${SED} "s|^([0-9]+).*$|\1|g") == 1 ]];
			}; then
				echo -en "URL (image): ${ID_URL}\n"
				read -p "URL (image): " ID_URL_IMG
				if [[ -n ${ID_URL_IMG} ]]; then
					echo "${ID_URL}"	>_id.url
					echo "${ID_URL_IMG}"	>>_id.url
				fi
			fi
			if [[ -z ${ID_URL_IMG} ]]; then
				return 1
			fi
			run_cmd "${FUNCNAME}: images" ${WGET_C} --output-document="image.${ID_URL_NUM}.html"				"${ID_URL_IMG}" #>>> || return 1
			strip_file image.${ID_URL_NUM}.html
			if { [[ ! -s image.${ID_URL_NUM}.html ]] && [[ ! -f image.${ID_URL_NUM}.html.null ]]; }; then
				${LL} image.${ID_URL_NUM}.html*
				return 1
			fi
			declare IMGS=($(${SED} \
					-e "s| \"(https://img.discogs.com/[^\"]+)|\n\1\n|g" \
					-e "s|src=\"(https://img.discogs.com/[^\"]+)|\n\1\n|g" \
					-e "s|content=\"(https://img.discogs.com/[^\"]+)|\n\1\n|g" \
					image.${ID_URL_NUM}.html |
				${GREP} "^https://img.discogs.com/" |
				${GREP} "quality\(90\)" |
				${GREP} "format\(jpeg\)" |
				sort -u
			))
			declare IMG=
			for FILE in ${IMGS[@]}; do
				IMG="$(echo "${FILE}" | ${SED} \
					-e "s|^.+R-||g" \
					-e "s|.jpeg.jpg||g" \
				)"
				if [[ ! -s image.${IMG}.jpg ]]; then
					run_cmd "${FUNCNAME}: images" ${WGET_C} --output-document="image.${IMG}.jpg"			"${FILE}" || return 1
				fi
			done
			touch _image.${ID_URL_NUM}.${DATE}
		fi
		if {
			[[ ! -f $(${LS} _image.${ID_MBID}.[0-9-]*) ]] &&
			[[ ${ID_MBID} != null ]];
		}; then
			run_cmd "${FUNCNAME}: images" ${WGET_C} --output-document="image.${ID_MBID}.json"				http://coverartarchive.org/release/${ID_MBID}		#>>> || return 1
#>>>			run_cmd "${FUNCNAME}: images" ${WGET_C} --output-document="image.${ID_MBID}.front.jpg"				http://coverartarchive.org/release/${ID_MBID}/front	|| return 1
#>>>			run_cmd "${FUNCNAME}: images" ${WGET_C} --output-document="image.${ID_MBID}.back.jpg"				http://coverartarchive.org/release/${ID_MBID}/back	|| return 1
			strip_file image.${ID_MBID}.json
			if { [[ ! -s image.${ID_MBID}.json ]] && [[ ! -f image.${ID_MBID}.json.null ]]; }; then
				${LL} image.${ID_MBID}.json*
				return 1
			fi
			declare IMGS=($(jq --raw-output '.images[] | .id'								image.${ID_MBID}.json))
#>>>			declare FRNT=($(jq --raw-output '.images[] | select(.types[]? | contains("Front")) | .id'			image.${ID_MBID}.json))
#>>>			declare BACK=($(jq --raw-output '.images[] | select(.types[]? | contains("Back")) | .id'			image.${ID_MBID}.json))
#>>>			declare MEDI=($(jq --raw-output '.images[] | select(.types[]? | contains("Medium")) | .id'			image.${ID_MBID}.json))
			for FILE in ${IMGS[@]}; do
				if [[ ! -s image.${ID_MBID}.${FILE}.jpg ]]; then
					run_cmd "${FUNCNAME}: images" ${WGET_C} --output-document="image.${ID_MBID}.${FILE}.jpg"	http://coverartarchive.org/release/${ID_MBID}/${FILE}.jpg || return 1
				fi
			done
			touch _image.${ID_MBID}.${DATE}
		fi
		run_cmd "${FUNCNAME}: images"
		function image_select {
			declare IMAGE="${1}" && shift
			if [[ ! -s _image.${IMAGE}.jpg ]]; then
				echo -en "\n"
				${LS} image.*.{png,jpg} | while read -r FILE; do
					echo -en "${FILE}\n"
				done
				echo -en "_image.front.jpg\n"
				read -p "IMAGE (${IMAGE}): " FILE
				if [[ -n ${FILE} ]]; then
					${LN} ${FILE} _image.${IMAGE}.jpg || return 1
				fi
			fi
			return 0
		}
		{ ${IMAGE_CMD} image.*.{png,jpg} 2>/dev/null || return 1; } &
		image_select front	|| return 1
		image_select back	|| return 1
		image_select media	|| return 1
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
		${IMAGE_CMD} _image.*.{png,jpg} 2>/dev/null || return 1
	fi
#>>>	run_cmd "${FUNCNAME}: output" ${LL} _image.*

	if [[ ! -s _metadata ]]; then
		run_cmd "${FUNCNAME}: metadata"
		${RSYNC_U} audio.cue _metadata.edit
		declare MULTI="false"
		declare TRCKS=($(jq --raw-output '.media[].tracks[] | .position'						id.${ID_MBID}.json))
		declare TITLE="$(jq --raw-output '.title'									id.${ID_MBID}.json)"
		declare RYEAR="$(jq --raw-output '.date'									id.${ID_MBID}.json | ${SED} "s|-.+||g")"
		declare PRFMR=
		declare -a TITLES
		declare -a PRFMRS
		for FILE in ${TRCKS[@]}; do
			TITLES[${FILE}]="$(jq --raw-output '.media[].tracks[] | select(.position == '${FILE}') | .title'	id.${ID_MBID}.json)"
			PRFMRS[${FILE}]="$(
				declare NUM="0"
				declare -a ARTISTS
				shopt -s lastpipe
				jq --raw-output '.media[].tracks[] | select(.position == '${FILE}') | ."artist-credit"[].name'	id.${ID_MBID}.json |
					while read -r FILE; do
						ARTISTS[${NUM}]="${FILE}"
						NUM="$((${NUM}+1))"
					done
				if (( ${#ARTISTS[@]} > 1 )); then
					for FILE in "${ARTISTS[@]}"; do
						echo -en "${FILE}${FLAC_ADIV//\\}"
					done | ${SED} "s|${FLAC_ADIV}$||g"
				else
					echo -en "${ARTISTS[0]}"
				fi
			)"
			if {
				(( ${FILE} > 1 )) &&
				[[ ${PRFMRS[$FILE]} != ${PRFMRS[$((${FILE}-1))]} ]];
			}; then
				MULTI="true"
			fi
		done
		if ! ${MULTI}; then
			PRFMR="${PRFMRS[1]}"
		else
			PRFMR="${FLAC_MANY}"
		fi
		${SED} -i \
			-e "/^REM/d" \
			-e "s|^(CATALOG)|TITLE \"${TITLE}\"\nPERFORMER \"${PRFMR}\"\nREM ${RYEAR}\n\1|g" \
			_metadata.edit
		for FILE in ${TRCKS[@]}; do
			${SED} -i "s|^(  TRACK 0?${FILE} AUDIO)$|\1\n    TITLE \"${TITLES[$FILE]}\"\n    PERFORMER \"${PRFMRS[$FILE]}\"|g" _metadata.edit
		done
		${MV} _metadata.edit _metadata
		${EDITOR} _metadata
	fi
	if [[ ! -s _metadata.name ]]; then
		run_cmd "${FUNCNAME}: metadata"
		OUTPUT="$(
			namer "$(${SED} -n "s|^PERFORMER \"(.+)\"$|\1|gp" _metadata)"
		).$(
			namer "$(${SED} -n "s|^TITLE \"(.+)\"$|\1|gp" _metadata)"
		).$(
			namer "$(${SED} -n "s|^REM ([0-9]{4})$|\1|gp" _metadata)"
		)"
		OUTPUT="$(echo "${OUTPUT}" | ${SED} "s|^$(namer "${FLAC_MANY}").||g")"
		echo "${OUTPUT}" >_metadata.name
		${EDITOR} _metadata.name
	fi
	OUTPUT="$(cat _metadata.name)"
	if {
		[[ -z ${OUTPUT} ]] ||
		[[ -n $(echo "${OUTPUT}" | ${GREP} "^[./]+") ]];
	}; then
		return 1
	fi
	if [[ ! -s _metadata.tags ]]; then
		run_cmd "${FUNCNAME}: metadata"
		echo -en "VERSION=${DATE}"										>>_metadata.tags
		[[ ${DATE} != $(cat .exported) ]] && echo -en " ($(cat .exported))"					>>_metadata.tags
		echo -en "\n"												>>_metadata.tags
		echo -en "TITLE="		>>_metadata.tags;	${SED} -n "s|^PERFORMER \"(.+)\"$|\1|gp"	_metadata | tr -d '\n' >>_metadata.tags
		echo -en "${FLAC_TDIV//\\}"	>>_metadata.tags;	${SED} -n "s|^TITLE \"(.+)\"$|\1|gp"		_metadata | tr -d '\n' >>_metadata.tags
		echo -en "\n"												>>_metadata.tags
		echo -en "ALBUM="		>>_metadata.tags;	${SED} -n "s|^TITLE \"(.+)\"$|\1|gp"		_metadata >>_metadata.tags
		echo -en "ARTIST="		>>_metadata.tags;	${SED} -n "s|^PERFORMER \"(.+)\"$|\1|gp"	_metadata >>_metadata.tags
		echo -en "DATE="		>>_metadata.tags;	${SED} -n "s|^REM ([0-9]{4})$|\1|gp"		_metadata >>_metadata.tags
		for FILE in $(
			${SED} -n "s|^ +TRACK ([0-9]+) AUDIO$|\1|gp" _metadata
		); do
			${GREP} -A4 "^ +TRACK ${FILE} AUDIO$" _metadata |
				tr -d '\n' |
				${SED} "s|$|\n|g" |
				${SED} "s|^.+TITLE \"([^\"]+)\".+PERFORMER \"([^\"]+)\".+INDEX 01 ([0-9]{2}):([0-9]{2}):([0-9]{2}).*$|CHAPTER0${FILE}=00:\3:\4.000\nCHAPTER0${FILE}NAME=${FILE}${FLAC_NDIV}\1${FLAC_TDIV}\2|g" |
				cat >>_metadata.tags
		done
		if [[ $(${SED} -n "s|^PERFORMER \"(.+)\"$|\1|gp" _metadata) == ${FLAC_MANY} ]]; then
			${SED} -i "s|^(TITLE=)${FLAC_MANY}${FLAC_TDIV}|\1|g" _metadata.tags
		else
			${SED} -i "s|^(CHAPTER0.+)${FLAC_TDIV}.+$|\1|g" _metadata.tags
		fi
	fi
	run_cmd "${FUNCNAME}: output" cat _metadata.name
	run_cmd "${FUNCNAME}: output" cueprint --input-format cue _metadata
	run_cmd "${FUNCNAME}: output" cat _metadata
	run_cmd "${FUNCNAME}: output" cat _metadata.tags

	run_cmd "${FUNCNAME}: encode"
	declare TAGS="$(
		cat _metadata.tags | while read -r FILE; do
			echo "--tag=\"${FILE}\""
		done
	)"
	if [[ ! -s ${OUTPUT}.flac ]]; then
		eval run_cmd "\"${FUNCNAME}: encode\"" flac \
			${FLAC_OPTS} \
			\
			--cuesheet="\"_metadata\"" \
			--tag-from-file="\"CUESHEET=_metadata\"" \
			${TAGS} \
			\
			--picture="\"1||||_image.icon.png\"" \
			--picture="\"3||||_image.front.jpg\"" \
			--picture="\"4||||_image.back.jpg\"" \
			--picture="\"6||||_image.media.jpg\"" \
			\
			"${@}" \
			--output-name="\"${OUTPUT}.flac\"" \
			audio.wav \
			|| return 1
	fi

	if [[ -f ${OUTPUT}.flac ]]; then
		if [[ ! -s ${OUTPUT}.wav ]]; then
#>>>			run_cmd "${FUNCNAME}: verify"	flac --force --analyze	${OUTPUT}.flac || return 1
#>>>			run_cmd "${FUNCNAME}: verify"	flac --force --test	${OUTPUT}.flac || return 1
			run_cmd "${FUNCNAME}: verify"	flac --force --decode	${OUTPUT}.flac || return 1
			if ! run_cmd "${FUNCNAME}: verify" diff ${DIFF_OPTS} ${OUTPUT}.wav audio.wav; then
				return 1
			fi
		fi
		run_cmd "${FUNCNAME}: info" ffmpeg -i				${OUTPUT}.flac #>>> || return 1
		run_cmd "${FUNCNAME}: info" metaflac --list			${OUTPUT}.flac | ${GREP} -A4 "^METADATA" | ${GREP} -v "^--$" #>>> || return 1
		run_cmd "${FUNCNAME}: info" metaflac --export-cuesheet-to=-	${OUTPUT}.flac || return 1
		run_cmd "${FUNCNAME}: info" metaflac --export-tags-to=-		${OUTPUT}.flac || return 1
	fi

	run_cmd "${FUNCNAME}: archive"
	if [[ ! -s ${OUTPUT}.tar.xz ]]; then
		function tarfiles {
			find ./ -maxdepth 1 ! -type d | ${SED} "s|^\./||g" | sort
		}
		run_cmd "${FUNCNAME}: archive" ${FLAC_HASH} $(tarfiles) \
			| ${GREP} -v \
				-e " _checksum" \
				-e " audio_" \
				-e " ${OUTPUT//+/\\+}" \
			| tee _checksum
			[[ ${PIPESTATUS[0]} != 0 ]] && return 1
		run_cmd "${FUNCNAME}: archive" tar --xz -cvv \
			--exclude="audio.*" \
			--exclude="audio_*" \
			--exclude="${OUTPUT}*" \
			-f ${OUTPUT}.tar.xz $(tarfiles) \
			|| return 1
	fi
	while [[ -n $(metaflac --list --block-type="PICTURE" --block-number="$((${FLAC_BLCK}+1))" ${OUTPUT}.flac 2>/dev/null) ]]; do
		run_cmd "${FUNCNAME}: archive" metaflac \
			--block-type="PICTURE" \
			--block-number="$((${FLAC_BLCK}+1))" \
			--remove \
			${OUTPUT}.flac \
			|| return 1
	done

	run_cmd "${FUNCNAME}: embed"
	declare TGZ_LST="$(metaflac --list --block-type="PICTURE" --block-number="${FLAC_BLCK}" ${OUTPUT}.flac 2>/dev/null | ${SED} -n "s|^ +description: ||gp")"
	declare TGZ_OUT="$(metaflac --block-number="${FLAC_BLCK}" --export-picture-to=- ${OUTPUT}.flac 2>/dev/null | ${FLAC_HASH} | ${GREP} -o "^${FLAC_HASH_CHARS}")"
	declare TGZ_FIL="$(${FLAC_HASH} ${OUTPUT}.tar.xz | ${GREP} -o "^${FLAC_HASH_CHARS}")"
	if {
		[[ ${TGZ_LST} != ${TGZ_OUT} ]] ||
		[[ ${TGZ_LST} != ${TGZ_FIL} ]];
	}; then
		if [[ -n $(metaflac --list --block-type="PICTURE" --block-number="${FLAC_BLCK}" ${OUTPUT}.flac 2>/dev/null) ]]; then
			run_cmd "${FUNCNAME}: archive" metaflac \
				--block-type="PICTURE" \
				--block-number="${FLAC_BLCK}" \
				--remove \
				${OUTPUT}.flac \
				|| return 1
		fi
		run_cmd "${FUNCNAME}: archive" metaflac \
			--import-picture-from="0|image/png|$(${FLAC_HASH} ${OUTPUT}.tar.xz | ${GREP} -o "^${FLAC_HASH_CHARS}")|32x32x32|${OUTPUT}.tar.xz" \
			${OUTPUT}.flac \
			|| return 1
	fi

	run_cmd "${FUNCNAME}: validate"
	if [[ ! -d ${OUTPUT}.flac.dir ]]; then
		flac_unpack ${OUTPUT}.flac
		if {
			! run_cmd "${FUNCNAME}: unpack" diff ${DIFF_OPTS} -r \
				--exclude="audio_*" \
				--exclude="${OUTPUT}*" \
				${PWD} ${OUTPUT}.flac.dir;
		}; then
			return 1
		fi
	fi

	run_cmd "${FUNCNAME}: complete"
	run_cmd "${FUNCNAME}: output" metaflac \
		--block-number="${FLAC_BLCK}" \
		--export-picture-to=- \
		${OUTPUT}.flac \
		| tar --xz -tvv -f -
#>>>	run_cmd "${FUNCNAME}: output" ${LL}
	run_cmd "${FUNCNAME}: output" ${LL} $(find ./ -maxdepth 1 -empty | ${SED} "s|^\./||g" | sort)
	run_cmd "${FUNCNAME}: output" ${DU} -cms ${OUTPUT}*
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
	if [[ ! -d ${UNPACK}.dir ]]; then
		${MKDIR} ${UNPACK}.dir
		run_cmd "${FUNCNAME}" metaflac \
			--block-number="${FLAC_BLCK}" \
			--export-picture-to=- \
			${UNPACK} \
			| tar --xz -xvv -C ${UNPACK}.dir -f - \
			|| return 1
		run_cmd "${FUNCNAME}" metaflac --export-cuesheet-to=${UNPACK}.dir/audio.cue		${UNPACK}		|| return 1
		${SED} -i -e "/^REM/d" -e "s|^(FILE \").+$|\1audio.wav\" WAVE|g"			${UNPACK}.dir/audio.cue	|| return 1
		run_cmd "${FUNCNAME}" flac --force --decode --output-name=${UNPACK}.dir/audio.wav	${UNPACK}		|| return 1
		(cd ${UNPACK}.dir && run_cmd "${FUNCNAME}" ${FLAC_HASH} --check _checksum)		|| return 1
	fi
	declare DESTNAME="$(realpath ${ADDARG} 2>/dev/null)"
	declare BASENAME="$(cat ${UNPACK}.dir/_metadata.name)"
	if [[ ${1} == +([0-9]) ]]; then
		shopt -s lastpipe
		while [[ ${1} == +([0-9]) ]]; do
			FILE="${1}" && shift
			if [[ ${FILE} != [0-9][0-9] ]]; then
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
		if [[ ${TRACKR} != [0-9][0-9] ]]; then
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
		COUNTR="$((${COUNTR/#0}+1))"
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
		echo -en "VERSION=${DATE}${FLAC_TDIV//\\}"						>_metadata.${DONAME}
		${SED} -n "s|^VERSION=(.+)$|\1|gp" _metadata.tags					>>_metadata.${DONAME}
		echo -en "ALBUM="	>>_metadata.${DONAME}; ${SED} -n "s|^TITLE \"(.+)\"$|\1|gp"	_metadata >>_metadata.${DONAME}
		echo -en "DATE="	>>_metadata.${DONAME}; ${SED} -n "s|^REM ([0-9]{4})$|\1|gp"	_metadata >>_metadata.${DONAME}
		echo -en "TRACKNUMBER=${DONAME}\n"							>>_metadata.${DONAME}
		${GREP} -A4 "^ +TRACK ${DONAME} AUDIO$" _metadata |
			${SED} \
				-e "/^ +TRACK [0-9]+ AUDIO$/d" \
				-e "/^ +INDEX [0-9]+ .+$/d" \
				-e "s|^ *||g" \
				-e "s| \"|=|g" \
				-e "s|\"$||g" \
				\
				-e "s|^PERFORMER|ARTIST|g" \
				-e "/^ISRC /d" \
			>>_metadata.${DONAME}
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

################################################################################

  if { [[ -s ${SOURCE} ]] && [[ -n $(file ${SOURCE} | ${GREP} "FLAC") ]]; }; then	flac_unpack	"${SOURCE}" "${@}" || exit 1
elif { [[ -s ${SOURCE} ]] && [[ ${SOURCE/%.m3u} != ${SOURCE} ]]; }; then		flac_playlist	"${SOURCE}" "${@}" || exit 1
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
