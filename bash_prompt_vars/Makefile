export GOPATH=$(CURDIR)/go_modules
export GO111MODULES=on
GO_JUNIT_REPORT := $(GOPATH)/bin/go-junit-report
JUNIT_FILE := xunit.xml

sources = $(wildcard *.go)

.PHONY: build
build: bash_prompt_vars  ## Build the project

bash_prompt_vars: $(GOPATH)/.deps $(sources)
	go build -v -o $@

.PHONY: deps
deps: $(GOPATH)/.deps  ## Pull in dependencies

$(GOPATH)/.deps: $(sources)
	go get -v
	touch $@

.PHONY: run
run: $(GOPATH)/.deps  ## Run the program
	go run .

.PHONY: test
test: $(JUNIT_FILE)  ## Run unit tests

$(GO_JUNIT_REPORT):
	go get -u github.com/jstemmer/go-junit-report

.PHONY: test-coverage
test-coverage: coverage.out  ## Show test coverage
	go tool cover -html=$<

$(JUNIT_FILE): $(GO_JUNIT_REPORT) gotest.out
	$< < gotest.out > $@


coverage.out gotest.out: $(sources)  ## Run tests, if necessary
	go test -v -race -coverprofile=coverage.out 2>&1 | tee gotest.out && exit $${PIPESTATUS[0]}

$(GOPATH)/bin/goimports:
	go get -u golang.org/x/tools/cmd/goimports

.PHONY: format
format: $(GOPATH)/bin/goimports
	$(GOPATH)/bin/goimports -w $(sources)

.PHONY: clean
clean:  ## Remove temp/build files
	go clean -cache
	go clean -testcache
	go clean -modcache
	rm -rf go_modules $(JUNIT_FILE) gotest.out coverage.out bash_prompt_vars

.PHONY: help
help:  ## Show help for this Makefile
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
