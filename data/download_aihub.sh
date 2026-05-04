#!/bin/bash
# AI Hub 경구약제 이미지 데이터 다운로드 스크립트
# 데이터셋: 약품식별 인공지능 개발을 위한 경구약제 이미지 (dataSetSn=576)
#
# [버그 주의] aihubshell 기본 merge_parts()는 printf '%q'로 한글 파일명을 이스케이프하여
# find -name 패턴이 불일치 → 빈 zip 생성 버그. 이 스크립트는 bash glob으로 직접 병합.
#
# 사용법: bash data/download_aihub.sh
# 출력 경로: data/raw/aihub_pills/

APIKEY="931C539F-92DA-437E-9F3F-E90AD9009930"
DATASET="576"
BASE_URL="https://api.aihub.or.kr/down/0.6"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$SCRIPT_DIR/raw/aihub_pills"

merge_parts() {
    # .part0 파일 기준으로 prefix 추출 → bash glob으로 병합 (숫자 순 보장)
    while IFS= read -r -d '' part0; do
        prefix="${part0%.part0}"
        echo "  Merging: $(basename "$prefix")"
        ls -v "${prefix}".part* | xargs cat > "${prefix}"
        rm "${prefix}".part*
    done < <(find "$DEST" -name "*.part0" -print0)
}

flatten_structure() {
    # tar 해제 시 생기는 "166.약품식별..." / "01.데이터" 중간 폴더 제거
    local nested
    nested=$(find "$DEST" -maxdepth 1 -type d -name "166.*" | head -1)
    if [ -n "$nested" ]; then
        local inner="$nested/01.데이터"
        if [ -d "$inner" ]; then
            # 1.Training, 2.Validation 등을 DEST로 직접 이동
            for d in "$inner"/*/; do
                name="$(basename "$d")"
                if [ -d "$DEST/$name" ]; then
                    cp -rn "$d" "$DEST/$name/" 2>/dev/null || true
                    rm -rf "$d"
                else
                    mv "$d" "$DEST/"
                fi
            done
        fi
        rm -rf "$nested"
    fi
}

download_file() {
    local filekey="$1"
    echo "=== Downloading key: $filekey ==="

    curl -L -o "$DEST/download.tar" \
        -H "apikey:$APIKEY" \
        "${BASE_URL}/${DATASET}.do?fileSn=${filekey}"

    if [ $? -ne 0 ]; then
        echo "ERROR: curl 실패 (key: $filekey)"
        rm -f "$DEST/download.tar"
        return 1
    fi

    tar -xf "$DEST/download.tar" -C "$DEST" && rm -f "$DEST/download.tar"
    flatten_structure
    merge_parts
    echo "=== 완료: $filekey ==="
}

mkdir -p "$DEST"

# ──────────────────────────────────────────────
# 다운로드할 파일키 목록
# 라벨링데이터만으로 클래스 수·분포·어노테이션 포맷 파악 가능
# 원천데이터(이미지)는 단일 파일당 90GB+ → 서버에서 수신 권장
# ──────────────────────────────────────────────
FILEKEYS=(
    # [라벨링] Training 조합 (TL_1~8_조합, ~8MB × 8)
    66065 66066 66067 66068 66069 66070 66071 66072
    # [라벨링] Training 단일 (TL_1~81_단일, ~14~94MB × 81)
    66073 66074 66075 66076 66077 66078 66079 66080
    66081 66082 66083 66084 66085 66086 66087 66088
    66089 66090 66091 66092 66093 66094 66095 66096
    66097 66098 66099 66100 66101 66102 66103 66104
    66105 66106 66107 66108 66109 66110 66111 66112
    66113 66114 66115 66116 66117 66118 66119 66120
    66121 66122 66123 66124 66125 66126 66127 66128
    66129 66130 66131 66132 66133 66134 66135 66136
    66137 66138 66139 66140 66141 66142 66143 66144
    66145 66146 66147 66148 66149 66150 66151 66152 66153
    # [라벨링] Validation 조합+단일 전체 (VL_1_조합, VL_1~10_단일)
    66243 66244 66245 66246 66247 66248 66249 66250 66251 66252 66253
    # [원천] Training 조합 1개 (TS_1_조합, 3.46GB) — 이미지 구조 샘플용
    66154
)

for key in "${FILEKEYS[@]}"; do
    download_file "$key"
done

echo "=== 모든 다운로드 완료 ==="
echo "출력 경로: $DEST"
