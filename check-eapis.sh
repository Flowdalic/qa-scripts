#!/bin/bash
# Arguments:
# $1: output directory. Defaults to eapi-usage.

. /lib/gentoo/functions.sh
dir=${1}
if [[ -n ${1} && ! -d ${dir} ]] ; then
	eerror "Output directory given (${dir}) is not a directory! Exiting."
	exit 1
elif [[ -z ${dir} ]] ; then
	ewarn "No output directory argument given! Defaulting to 'eapi-usage'."
	dir=eapi-usage
fi

REPO_PATH=$(portageq get_repo_path ${EROOT:-/} gentoo || exit 1)

mkdir -p ${dir} || exit 1

ebegin "Getting list of supported EAPIs"
eapi_list=$(python3 -c 'import portage.repository.config; print("\n".join(list(portage._supported_eapis)))' || exit 1)
eend $?
einfo "EAPI list:" ${eapi_list}

TMPDIR="$(mktemp -d || exit 1)"

einfo "Working in TMPDIR=${TMPDIR}"
pushd "${TMPDIR}" &>/dev/null || exit 1
mkdir -p eapi-usage || exit 1
cd eapi-usage || exit 1

for eapi in ${eapi_list[@]} ; do
	[[ -f ${eapi}.txt ]] && rm -r ${eapi}.txt
	touch ${eapi}.txt
done

ebegin "Finding ebuilds"
(
	for ebuild in $(find "${REPO_PATH}/metadata/md5-cache" -mindepth 2 -maxdepth 2 -type f -name '*-[0-9]*') ; do
		cpf=$(echo ${ebuild} | rev | cut -d/ -f1-2 | rev)
		eapi=$(grep -oi "eapi=.*" ${ebuild} | sed -e 's:EAPI=::')

		echo "${cpf}" >> ${eapi}.txt
	done
) || { eend $? || exit 1; }
eend ${?}

ebegin "Sorting EAPI files"
for eapi in ${eapi_list[@]} ; do
	sort -u ${eapi}.txt > ${eapi}.txt.sorted
	mv ${eapi}.txt.sorted ${eapi}.txt
done || { eend $? || exit 1; }
eend $?

popd &>/dev/null || exit 1
mv ${TMPDIR}/eapi-usage/*.txt ${dir}/ || exit 1

rm -r "${TMPDIR}" || exit 1
