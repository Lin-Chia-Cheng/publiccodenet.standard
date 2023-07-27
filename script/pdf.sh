#!/bin/bash
# SPDX-License-Identifier: CC0-1.0
# SPDX-FileCopyrightText: 2021-2023 The Foundation for Public Code <info@publiccode.net>, https://standard.publiccode.net/AUTHORS

# This script is used to generate a PDF from the html generated by Jekyll.
# This script is used during the release process (see ../docs/releasing.md)

if [ "_${1}_" == "__" ]; then
	echo "must specify a VERSION"
	exit 1
fi
VERSION="${1}"

function weasyprint_version() {
	weasyprint --version \
		| sed -e's/[^0-9]*\([0-9\.]*\).*/\1/'
}

function temp_weasyprint_info() {
	if [ $TMP_WEASYPRINT -gt 0 ]; then
		WEASY_PRINT_VER=$(weasyprint_version)
		echo "================================================="
		echo "temp WeasyPrint installed, version $WEASY_PRINT_VER"
		echo "to use this version outside of this script,"
		echo "type the following command:"
		echo
		echo "$ source /tmp/weasyprint/venv/bin/activate"
		echo "================================================="
	fi
}

function ensure_good_weasyprint () {
	WEASY_PRINT_VER=$(weasyprint_version)
	echo "WEASY_PRINT_VER='$WEASY_PRINT_VER'"

	if [ "_${WEASY_PRINT_VER}_" != "__" ]; then
		WP_MAJOR_VERSION=$(echo "${WEASY_PRINT_VER}" | cut -f1 -d'.')
		WP_MINOR_VERSION=$(echo "${WEASY_PRINT_VER}" | cut -f2 -d'.')
	else
		WP_MAJOR_VERSION=0
		WP_MINOR_VERSION=0
	fi

	if [ "$WP_MAJOR_VERSION" -lt 57 ]; then
		echo "WeasyPrint version: $WEASY_PRINT_VER less than 57"
	        echo "installing new weasyprint"
		pushd /tmp
		rm -rf weasyprint
		git clone https://github.com/Kozea/WeasyPrint.git weasyprint
		cd weasyprint
		python3 -m venv venv
	        source venv/bin/activate
	        pip install weasyprint
		TMP_WEASYPRINT=1
		echo
		temp_weasyprint_info
		echo
		popd
	fi
	if [ "_${TMP_WEASYPRINT}_" == "__" ]; then
		TMP_WEASYPRINT=0
	fi
}
ensure_good_weasyprint

JEKYLL_PDF_PORT=9000
JEKYLL_PDF_DIR=_build_pdf
rm -rf $JEKYLL_PDF_DIR

PAGES_REPO_NWO=publiccodenet/standard \
	bundle exec jekyll serve \
		--port=$JEKYLL_PDF_PORT \
		--destination=$JEKYLL_PDF_DIR &
JEKYLL_PID=$!
function cleanup() {
	echo "Killing JEKYLL_PID: $JEKYLL_PID"
	kill $JEKYLL_PID
}
trap cleanup EXIT # stop the jekyll serve

MAX_LOOPS=100
LOOPS=0
while ! curl "http://localhost:$JEKYLL_PDF_PORT" >/dev/null 2>&1 ; do
	LOOPS=$(( $LOOPS + 1 ));
	echo "try $LOOPS, waiting to connect ..."
	sleep 1;
	if [ $LOOPS -gt $MAX_LOOPS ]; then
		echo "exceeds MAX_LOOPS";
		exit 1;
	fi
done

# give it one more second
sleep 1;

echo
weasyprint --presentational-hints \
	"http://localhost:$JEKYLL_PDF_PORT/standard-print.html" \
	standard-for-public-code-$VERSION.pdf
ls -l	standard-for-public-code-$VERSION.pdf

echo
weasyprint --presentational-hints \
	"http://localhost:$JEKYLL_PDF_PORT/foreword-print.html" \
	standard-for-public-code-foreword-$VERSION.pdf
ls -l	standard-for-public-code-foreword-$VERSION.pdf

echo
weasyprint --presentational-hints \
	"http://localhost:$JEKYLL_PDF_PORT/print-cover.html" \
	standard-cover-$VERSION.pdf
ls -l	standard-cover-$VERSION.pdf

echo
weasyprint --presentational-hints \
	"http://localhost:$JEKYLL_PDF_PORT/docs/review-template.html" \
	standard-review-template-$VERSION.pdf
ls -l	standard-review-template-$VERSION.pdf

echo
weasyprint --presentational-hints \
	"http://localhost:$JEKYLL_PDF_PORT/docs/checklist.html" \
	standard-checklist-$VERSION.pdf
ls -l	standard-checklist-$VERSION.pdf

echo
if ! pandoc --version ; then
	echo "'pandoc' not installed, skipping .epub version"
	echo "'pandoc' should be available from the package manager, e.g.:"
	echo
	echo "        sudo apt install -y pandoc"
	echo
else
	pandoc $JEKYLL_PDF_DIR/standard-print.html \
		-o standard-for-public-code-$VERSION.epub
	ls -l standard-for-public-code-$VERSION.epub
fi

echo
if ! qpdf --version ; then
	echo "'qpdf' not installed, skipping combined-for-print version"
	echo "'qpdf' should be available from the package manager, e.g.:"
	echo
	echo "        sudo apt install -y qpdf"
	echo
else
	qpdf --empty --pages \
		standard-for-public-code-foreword-$VERSION.pdf \
		standard-for-public-code-$VERSION.pdf \
		-- \
		standard-for-public-code-print-$VERSION.pdf
	ls -l standard-for-public-code-print-$VERSION.pdf
fi

echo
temp_weasyprint_info

ls -l *.pdf *.epub

echo "done"
