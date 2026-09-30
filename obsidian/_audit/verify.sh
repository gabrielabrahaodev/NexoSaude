#!/bin/sh
# verify.sh — verificacao automatizada do vault NexoSaude (10 checagens).
# Uso: bash obsidian/_audit/verify.sh   (a partir da raiz do repo)
# Saida: 0 = tudo PASS, 1 = algum FAIL, 2 = somente WARN.
# Requer: sh, find, grep, sed, awk, sort, uniq, wc, date (POSIX).
# Gerado em 2026-09-30, ciclo de consolidacao. Sem dependencias externas.

set -u
HERE=$(dirname "$0")
VAULT=$(cd "$HERE/.." && pwd)
LOG="$HERE/verification-log.md"
TMPD="${TMPDIR:-/tmp}/vault-verify-$$"
mkdir -p "$TMPD"

PASS=0
WARN=0
FAILC=0
ROWS=""
FAILDETAIL=""

record() {
  ROWS="$ROWS
| $1 | $2 | $3 |"
  case "$2" in
    PASS) PASS=$((PASS + 1)) ;;
    WARN) WARN=$((WARN + 1)) ;;
    FAIL) FAILC=$((FAILC + 1)) ;;
  esac
}

faildetail() {
  FAILDETAIL="$FAILDETAIL
- $1"
}

# Lista de notas (relativas ao vault), fora de .obsidian.
NOTES="$TMPD/notes.txt"
(cd "$VAULT" && find . -name .obsidian -prune -o -type f -name '*.md' -print | sort | sed 's#^./##' | sort) > "$NOTES"
NFILES=$(wc -l < "$NOTES" | tr -d ' ')

# Basenames validos (sem extensao) + caminhos relativos (sem extensao) + aliases.
BASES="$TMPD/bases.txt"
: > "$BASES"
while IFS= read -r f; do
  b=$(basename "$f" .md)
  printf '%s\n' "$b" >> "$BASES"
  printf '%s\n' "${f%.md}" >> "$BASES"
done < "$NOTES"
# Aliases de frontmatter: linhas "- x" logo apos "aliases:".
find "$VAULT" -name .obsidian -prune -o -type f -name '*.md' -print0 | xargs -0 awk '
  FNR == 1 { fm = 0; inal = 0 }
  /^---$/ { if (fm == 0) { fm = 1; next } else if (fm == 1) { fm = 2 } next }
  fm == 1 && /^aliases:/ { inal = 1; next }
  fm == 1 && inal == 1 && /^[[:space:]]*-[[:space:]]+/ { sub(/^[[:space:]]*-[[:space:]]+/, ""); print; next }
  fm == 1 && inal == 1 && !/^[[:space:]]/ { inal = 0 }
' | sort -u >> "$BASES"
sort -u "$BASES" -o "$BASES"

in_bases() {
  grep -qxF "$1" "$BASES"
}

# ---- Checagem 1 — Frontmatter obrigatorio ----
C1_DIRS="foundation modules screens flows data-model decisions integrations runbooks tasks"
C1_OK=0
C1_TOT=0
C1_BAD=""
while IFS= read -r f; do
  case "$f" in
    foundation/*|modules/*|screens/*|flows/*|data-model/*|decisions/*|integrations/*|runbooks/*|tasks/*) ;;
    *) continue ;;
  esac
  C1_TOT=$((C1_TOT + 1))
  head12=$(head -12 "$VAULT/$f")
  ok=1
  first=$(printf '%s' "$head12" | sed -n '1p')
  [ "$first" = "---" ] || ok=0
  for k in title: type: status: updated:; do
    printf '%s' "$head12" | grep -q "^$k" || ok=0
  done
  if [ "$ok" = "1" ]; then C1_OK=$((C1_OK + 1)); else C1_BAD="$C1_BAD $f"; fi
done < "$NOTES"
if [ "$C1_TOT" -eq 0 ]; then
  record "1 | Frontmatter obrigatório" "FAIL" "nenhum arquivo no escopo"
  faildetail "check1: nenhum .md nas 9 pastas"
elif [ "$C1_OK" -eq "$C1_TOT" ]; then
  record "1 | Frontmatter obrigatório" "PASS" "$C1_OK/$C1_TOT"
else
  pct=$((C1_OK * 100 / C1_TOT))
  if [ "$pct" -gt 90 ]; then
    record "1 | Frontmatter obrigatório" "WARN" "$C1_OK/$C1_TOT ($pct%)"
  else
    record "1 | Frontmatter obrigatório" "FAIL" "$C1_OK/$C1_TOT ($pct%)"
    for b in $C1_BAD; do faildetail "check1: $b sem frontmatter completo"; done
  fi
fi

# ---- Checagem 2 — status na taxonomia ----
C2_BAD=""
while IFS= read -r f; do
  awk 'NR==1 && $0=="---" {fm=1; next} fm==1 && $0=="---" {exit} fm==1 && /^status:/ {print FILENAME": "$0}' "$VAULT/$f"
done < "$NOTES" > "$TMPD/status.txt"
while IFS= read -r line; do
  v=$(printf '%s' "$line" | sed 's#.*status: *##')
  case "$v" in
    draft|stable|deprecated) ;;
    *) C2_BAD="$C2_BAD $line" ;;
  esac
done < "$TMPD/status.txt"
if [ -z "$C2_BAD" ]; then
  record "2 | status na taxonomia" "PASS" "todos em draft/stable/deprecated"
else
  record "2 | status na taxonomia" "FAIL" "fora da taxonomia"
  for b in $C2_BAD; do faildetail "check2: $b"; done
fi

# ---- Checagem 3 — type na taxonomia ----
C3_BAD=""
while IFS= read -r f; do
  awk 'NR==1 && $0=="---" {fm=1; next} fm==1 && $0=="---" {exit} fm==1 && /^type:/ {print FILENAME": "$0}' "$VAULT/$f"
done < "$NOTES" > "$TMPD/type.txt"
while IFS= read -r line; do
  v=$(printf '%s' "$line" | sed 's#.*type: *##')
  case "$v" in
    module|screen|spec|adr|flow|runbook|integration|epic) ;;
    *) C3_BAD="$C3_BAD $line" ;;
  esac
done < "$TMPD/type.txt"
if [ -z "$C3_BAD" ]; then
  record "3 | type na taxonomia" "PASS" "todos na taxonomia"
else
  record "3 | type na taxonomia" "FAIL" "fora da taxonomia"
  for b in $C3_BAD; do faildetail "check3: $b"; done
fi

# ---- Checagem 4 — Wikilinks quebrados ----
# Escopo: fora de _audit/ e archive/. Ignora display (|x) e ancora (#y).
# Placeholders de template (com chaves) sao ignorados.
C4_BAD=""
SCAN4="$TMPD/scan4.txt"
grep -h -o '\[\[[^]]*\]\]' $(while IFS= read -r f; do
  case "$f" in _audit/*|archive/*) continue;; *) printf '%s' "$VAULT/$f ";; esac
done < "$NOTES") 2>/dev/null | sort -u > "$SCAN4" || true
while IFS= read -r link; do
  inner=$(printf '%s' "$link" | sed 's#^\[\[##; s#\]\]$##')
  tgt=$(printf '%s' "$inner" | cut -d'|' -f1 | cut -d'#' -f1)
  tgt=$(printf '%s' "$tgt" | sed 's#^[[:space:]]*##; s#[[:space:]]*$##')
  case "$tgt" in
    ""|!*|http*|*\{*|*\}*) continue ;;
  esac
  if [ -f "$VAULT/$tgt.md" ] || in_bases "$tgt"; then
    :
  else
    C4_BAD="$C4_BAD $tgt"
  fi
done < "$SCAN4"
C4_N=$(printf '%s' "$C4_BAD" | tr ' ' '\n' | grep -c . || true)
if [ "$C4_N" -eq 0 ]; then
  record "4 | Wikilinks quebrados" "PASS" "0"
elif [ "$C4_N" -le 3 ]; then
  record "4 | Wikilinks quebrados" "WARN" "$C4_N conhecidos"
  for b in $C4_BAD; do faildetail "check4: [[$b]] nao resolve"; done
else
  record "4 | Wikilinks quebrados" "FAIL" "$C4_N quebrados"
  for b in $C4_BAD; do faildetail "check4: [[$b]] nao resolve"; done
fi

# ---- Checagem 5 — Orfaos (sem backlinks) ----
ENTRY="00-index.md AGENTS.md CONTEXT.md CHANGELOG.md glossary.md"
ALLREFS="$TMPD/allrefs.txt"
grep -h -o '\[\[[^]]*\]\]' $(while IFS= read -r f; do printf '%s' "$VAULT/$f "; done < "$NOTES") 2>/dev/null | sed 's#^\[\[##; s#\]\]$##; s#[|].*$##; s/#.*$//' | sort -u > "$ALLREFS" || true
C5_N=0
C5_LIST=""
while IFS= read -r f; do
  case "$f" in
    _audit/*|_templates/*|archive/*) continue ;;
  esac
  skip=0
  for e in $ENTRY; do [ "$f" = "$e" ] && skip=1; done
  [ "$skip" = "1" ] && continue
  base=$(basename "$f" .md)
  rel="${f%.md}"
  hit=0
  if grep -qxF "$base" "$ALLREFS" || grep -qxF "$rel" "$ALLREFS"; then hit=1; fi
  if [ "$hit" = "0" ]; then C5_N=$((C5_N + 1)); C5_LIST="$C5_LIST $f"; fi
done < "$NOTES"
if [ "$C5_N" -eq 0 ]; then
  record "5 | Orfaos" "PASS" "0"
elif [ "$C5_N" -le 10 ]; then
  record "5 | Orfaos" "WARN" "$C5_N"
  for b in $C5_LIST; do faildetail "check5: orfao $b"; done
else
  record "5 | Orfaos" "FAIL" "$C5_N"
  for b in $C5_LIST; do faildetail "check5: orfao $b"; done
fi

# ---- Checagem 6 — TODOs pendentes (sempre WARN) ----
TODO_FILES="$TMPD/todo.txt"
grep -r -l 'TODO:' "$VAULT" --include='*.md' 2>/dev/null | grep -v '/_audit/' | grep -v '/.obsidian/' | sort | sed "s#^$VAULT/##" > "$TODO_FILES" || true
TODO_N=$(grep -r -o 'TODO:' "$VAULT" --include='*.md' 2>/dev/null | grep -v '/_audit/' | grep -v '/.obsidian/' | wc -l | tr -d ' ')
TOP10=$(while IFS= read -r f; do c=$(grep -o 'TODO:' "$VAULT/$f" 2>/dev/null | wc -l | tr -d ' '); printf '%s %s\n' "$c" "$f"; done < "$TODO_FILES" | sort -rn | head -10 | awk '{print $2" ("$1")"}' | tr '\n' ';' | sed 's#;$##')
record "6 | TODOs pendentes" "WARN" "$TODO_N em $(wc -l < "$TODO_FILES" | tr -d ' ') arquivos. Top: $TOP10"

# ---- Checagem 7 — Arquivos vazios ----
EMPTY_N=$(find "$VAULT" -name .obsidian -prune -o -type f -name '*.md' -size 0c -print 2>/dev/null | grep -v '/archive/' | wc -l | tr -d ' ')
if [ "$EMPTY_N" -eq 0 ]; then
  record "7 | Arquivos vazios" "PASS" "0"
else
  record "7 | Arquivos vazios" "FAIL" "$EMPTY_N"
  find "$VAULT" -name .obsidian -prune -o -type f -name '*.md' -size 0c -print 2>/dev/null | grep -v '/archive/' > "$TMPD/c7.txt"; while IFS= read -r f; do faildetail "check7: vazio $f"; done < "$TMPD/c7.txt"
fi

# ---- Checagem 8 — Casing kebab-case ----
C8_BAD=""
while IFS= read -r f; do
  case "$f" in _tools/*|archive/*) continue;; esac
  bn=$(basename "$f")
  if ! printf '%s' "$bn" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*\.md$'; then
    C8_BAD="$C8_BAD $f"
  fi
done < "$NOTES"
if [ -z "$C8_BAD" ]; then
  record "8 | Casing kebab-case" "PASS" "todos kebab"
else
  record "8 | Casing kebab-case" "WARN" "fora do padrao"
  for b in $C8_BAD; do faildetail "check8: $b nao e kebab-case"; done
fi

# ---- Checagem 9 — Escape indevido de pipe ----
# Linhas de tabela (comecam e terminam com pipe) com backslash-pipe fora de crases.
C9_N=$(grep -r -E '^[|].*\[|].*[|]$' "$VAULT" --include='*.md' 2>/dev/null | grep -v '/_audit/' | grep -v '/.obsidian/' | grep -v '`' | grep -F '\|' | wc -l | tr -d ' ')
if [ "$C9_N" -eq 0 ]; then
  record "9 | Escape de pipe" "PASS" "0"
else
  record "9 | Escape de pipe" "WARN" "$C9_N linhas"
  grep -r -E '^[|].*\[|].*[|]$' "$VAULT" --include='*.md' 2>/dev/null | grep -v '/_audit/' | grep -v '/.obsidian/' | grep -v '`' | grep -F '\|' | head -10 > "$TMPD/c9.txt"; while IFS= read -r l; do faildetail "check9: $l"; done < "$TMPD/c9.txt"
fi

# ---- Checagem 10 — Ver tambem resolve ----
C10_BAD=""
VT="$TMPD/vertambem.txt"
find "$VAULT" -name .obsidian -prune -o -type f -name '*.md' -print0 | xargs -0 awk '
  /^## Ver tamb/ {vt=1; next}
  vt==1 && /^## / {vt=0}
  vt==1 { while (match($0, /\[\[[^]]+\]\]/)) { print substr($0, RSTART+2, RLENGTH-4); $0 = substr($0, RSTART+RLENGTH) } }
' | sort -u > "$VT" || true
while IFS= read -r link; do
  tgt=$(printf '%s' "$link" | cut -d'|' -f1 | cut -d'#' -f1)
  tgt=$(printf '%s' "$tgt" | sed 's#^[[:space:]]*##; s#[[:space:]]*$##')
  case "$tgt" in ""|!*|http*|*\{*|*\}*) continue;; esac
  if [ -f "$VAULT/$tgt.md" ] || in_bases "$tgt"; then :; else C10_BAD="$C10_BAD $tgt"; fi
done < "$VT"
if [ -z "$C10_BAD" ]; then
  record "10 | Ver tambem resolve" "PASS" "todos resolvem"
else
  record "10 | Ver tambem resolve" "FAIL" "quebrados"
  for b in $C10_BAD; do faildetail "check10: [[$b]] em Ver tambem nao resolve"; done
fi

# ---- Relatorio ----
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
{
  printf '# Verification Log\n\n'
  printf 'Ultima execucao: %s\n' "$NOW"
  printf 'Vault: obsidian/\n'
  printf 'Arquivos verificados: %s\n' "$NFILES"
  printf '\n## Resultado\n\n'
  printf '| # | Checagem | Status | Detalhes |\n'
  printf '|---|---|---|---|\n'
  printf '%s\n' "$ROWS" | grep .
  printf '\n**Resumo:** %s PASS, %s WARN, %s FAIL\n' "$PASS" "$WARN" "$FAILC"
  printf '\n## Detalhes de falhas\n'
  if [ -z "$FAILDETAIL" ]; then printf 'nenhum\n'; else printf '%s\n' "$FAILDETAIL" | grep .; fi
  printf '\n## Historico\n'
  if [ -f "$LOG" ]; then grep -E '^- 20' "$LOG" 2>/dev/null || true; fi
  printf -- '- %s — PASS:%s WARN:%s FAIL:%s\n' "$NOW" "$PASS" "$WARN" "$FAILC"
} > "$LOG"

printf 'PASS:%s WARN:%s FAIL:%s\n' "$PASS" "$WARN" "$FAILC"
rm -rf "$TMPD"
if [ "$FAILC" -gt 0 ]; then exit 1; fi
if [ "$WARN" -gt 0 ]; then exit 2; fi
exit 0
