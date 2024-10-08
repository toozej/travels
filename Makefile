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
	BIND_ADDRESS = $(shell ip addr | grep 192 | awk '{print $$2}' | cut -d '/' -f 1)
	HOSTNAME = $(shell hostname -f)
else
	OPENER=open
	BIND_ADDRESS = localhost
	HOSTNAME = localhost
endif

MAGICK_CONVERT_BIN = $(shell command -v magick || command -v convert)


.PHONY: all pre-reqs update-hugo-version pre-commit pre-commit-install pre-commit-run build deploy serve serve-docker run clean test help

all: pre-reqs update-hugo-version pre-commit clean build serve ## Default workflow

pre-reqs: #pre-commit-install ## Install pre-commit hooks and necessary binaries
	command -v hugo || (command -v brew && brew install hugo) || curl --silent https://api.github.com/repos/gohugoio/hugo/releases/latest | grep "browser_download_url.*Linux-64bit.tar.gz" | grep "extended" | cut -d '"' -f 4 | wget -qO- -i - | tar -xz hugo && sudo mv hugo /usr/local/bin/hugo && sudo chmod +x /usr/local/bin/hugo && rm -f hugo_extended_*_Linux-64bit.tar.gz
	command -v magick || brew install imagemagick || sudo dnf install -y imagemagick || sudo apt install -y imagemagick

update-hugo-version: ## Updates Hugo version used throughout repo to latest
	@OLD_VERSION="0.132.2" && \
	VERSION=`curl -s https://api.github.com/repos/gohugoio/hugo/releases/latest | jq -r '.html_url' | cut -d "/" -f 8 | tr -d "v"`; \
	if [[ "$$OLD_VERSION" != "$$VERSION" ]]; then \
		echo "Updating Hugo from $$OLD_VERSION to $$VERSION"; \
		echo "$(CURDIR)/.github/workflows/hugo.yaml	$(CURDIR)/.devcontainer/devcontainer.json $(CURDIR)/Makefile" | xargs sed -i "" -e "s/$$OLD_VERSION/$$VERSION/g"; \
	else \
		echo "Already on current Hugo version $$VERSION"; \
	fi

gen-thumbnails: ## Generate thumbnails from full-sized static images
	find $(CURDIR)/static/images -not -path "*/fav/*" \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.JPG' \) -exec $(MAGICK_CONVERT_BIN) {} -resize x720 {}.thumb \;

build: gen-thumbnails ## Build website to "public" output directory
	hugo --gc --minify -d $(CURDIR)/public/
	$(OPTIMIZE)

serve: gen-thumbnails ## Run local web server
	echo "$(BIND_ADDRESS)"
	hugo server --gc --minify --bind=$(BIND_ADDRESS) --baseURL=http://$(HOSTNAME)/ --port=1313 --watch

serve-docker: ## Run Hugo server via Docker
	docker run --rm --name travels-hugo -p 1313:1313 -v $(CURDIR):/src --user $$(id -u):$$(id -g) floryn90/hugo:ext-alpine server --gc --minify -p 1313 --watch

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
