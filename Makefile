# Set sane defaults for Make
SHELL = bash
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# Set default goal such that `make` runs `make help`
.DEFAULT_GOAL := help

# Build functions
OPTIMIZE = find $(CURDIR)/public/ -not -path "*/static/*" \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.JPG' \) -print0 | \
xargs -0 -P8 -n2 mogrify -strip -thumbnail '1000>'

# Helper functions
OS = $(shell uname -s)
ifeq ($(OS), Linux)
	OPENER=xdg-open
else
	OPENER=open
endif

.PHONY: all pre-reqs pre-commit pre-commit-install pre-commit-run build deploy serve run clean test help

all: pre-reqs pre-commit clean build serve ## Default workflow

pre-reqs: pre-commit-install ## Install pre-commit hooks and necessary binaries
	command -v hugo || brew install hugo || sudo dnf install -y hugo || sudo apt install -y hugo
	command -v magick || brew install imagemagick || sudo dnf install -y imagemagick || sudo apt install -y imagemagick

gen-thumbnails: ## Generate thumbnails from full-sized static images
	find $(CURDIR)/static/images -not -path "*/fav/*" \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.JPG' \) -exec magick {} -resize x720 {}.thumb \;

build: gen-thumbnails ## Build website to "public" output directory
	hugo --gc --minify -d $(CURDIR)/public/
	$(OPTIMIZE)

serve: gen-thumbnails ## Run local web server
	$(OPENER) http://localhost:1313
	hugo server --gc --minify -p 1313 --watch

run: serve ## Run local web server

pre-commit: pre-commit-install pre-commit-run ## Install and run pre-commit hooks

pre-commit-install: ## Install pre-commit hooks and necessary binaries
	# shellcheck
	command -v shellcheck || sudo dnf install -y ShellCheck || sudo apt install -y shellcheck || brew install shellcheck
	# checkmake
	go install github.com/mrtazz/checkmake/cmd/checkmake@latest
	# syft
	command -v syft || curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
	# pre-commit
	command -v pre-commit || brew install pre-commit || sudo dnf install -y pre-commit || sudo apt install -y pre-commit
	# install and update pre-commits
	pre-commit install
	pre-commit autoupdate

pre-commit-run: ## Run pre-commit hooks against all files
	pre-commit run --all-files
	# manually run the following checks since their pre-commits aren't working or don't exist

clean: ## Remove any locally built files
	rm -rf $(CURDIR)/public/*

help: ## Display help text
	@grep -E '^[a-zA-Z_-]+ ?:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
