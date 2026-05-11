#!/bin/sh
set -eu

commit_ref=${1:-HEAD}
commit_message=${CI_COMMIT_MESSAGE:-$(git log -1 --pretty=%B "$commit_ref")}
latest_tag=$(git tag --list 'v*' | sort -V | tail -n 1 || true)

if [ -z "$latest_tag" ]; then
  latest_tag="v0.0.0"
fi

lower_message=$(printf '%s' "$commit_message" | tr '[:upper:]' '[:lower:]')
subject=$(printf '%s' "$lower_message" | head -n 1)

bump="skip"

manual_override=$(printf '%s' "$lower_message" | sed -n 's/.*release:[[:space:]]*\(major\|minor\|patch\|skip\).*/\1/p' | head -n 1)
if [ -n "$manual_override" ]; then
  bump="$manual_override"
elif printf '%s' "$lower_message" | grep -Eq 'breaking change|^[a-z]+\(.+\)!:|^[a-z]+!:'; then
  bump="major"
elif printf '%s' "$subject" | grep -Eq '^feat(\(.+\))?:'; then
  bump="minor"
elif printf '%s' "$subject" | grep -Eq '^(fix|perf|refactor)(\(.+\))?:'; then
  bump="patch"
fi

# Also scan message body lines for conventional commit patterns
# (covers GitHub merge commits where the PR body contains fix:/feat:)
if [ "$bump" = "skip" ]; then
  body=$(printf '%s' "$lower_message" | tail -n +2)
  if printf '%s' "$body" | grep -Eq '^feat(\(.+\))?:'; then
    bump="minor"
  elif printf '%s' "$body" | grep -Eq '^(fix|perf|refactor)(\(.+\))?:'; then
    bump="patch"
  fi
fi

# For GitHub merge commits ("Merge pull request #N from owner/branch"),
# use the branch name prefix as a last-resort fallback.
if [ "$bump" = "skip" ]; then
  pr_branch=$(printf '%s' "$subject" | sed -n 's/merge pull request #[0-9]* from [^/]*\/\(.*\)/\1/p')
  if [ -n "$pr_branch" ]; then
    branch_lower=$(printf '%s' "$pr_branch" | tr '[:upper:]' '[:lower:]')
    if printf '%s' "$branch_lower" | grep -Eq '^(feat|feature)/'; then
      bump="minor"
    elif printf '%s' "$branch_lower" | grep -Eq '^(fix|hotfix|bugfix|patch)/'; then
      bump="patch"
    fi
  fi
fi

version=${latest_tag#v}
major=$(printf '%s' "$version" | cut -d. -f1)
minor=$(printf '%s' "$version" | cut -d. -f2)
patch=$(printf '%s' "$version" | cut -d. -f3)

next_major=$major
next_minor=$minor
next_patch=$patch

case "$bump" in
  major)
    next_major=$((major + 1))
    next_minor=0
    next_patch=0
    ;;
  minor)
    next_minor=$((minor + 1))
    next_patch=0
    ;;
  patch)
    next_patch=$((patch + 1))
    ;;
  skip)
    ;;
  *)
    echo "Unsupported release bump: $bump" >&2
    exit 1
    ;;
esac

next_tag=""
if [ "$bump" != "skip" ]; then
  next_tag="v${next_major}.${next_minor}.${next_patch}"
fi

cat <<EOF
RELEASE_PREVIOUS_TAG=$latest_tag
RELEASE_BUMP=$bump
RELEASE_TAG=$next_tag
EOF