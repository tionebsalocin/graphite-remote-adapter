# Copyright 2015 The Prometheus Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

GO    := go
PROMU := $(GOPATH)/bin/promu
pkgs   = ./...

PREFIX                  ?= $(shell pwd)
BIN_DIR                 ?= $(shell pwd)
DOCKER_IMAGE_NAME       ?= graphite-remote-adapter
DOCKER_IMAGE_TAG        ?= $(subst /,-,$(shell git rev-parse --abbrev-ref HEAD))

ifdef DEBUG
	bindata_flags = -debug
endif


all: format build test mod-tidy

travis: style test clean assets mod-tidy

test:
	@echo ">> running tests"
	@$(GO) test -race -short $(pkgs)

style:
	@echo ">> checking code style"
	@! gofmt -d $(shell find . -path ./vendor -prune -o -name '*.go' -print) | grep '^'
	@echo ">> running golint"
	@$(GO) install golang.org/x/lint/golint@latest
	@golint -set_exit_status $(shell go list $(pkgs) | grep -v 'github.com/criteo/graphite-remote-adapter/ui')

format:
	@echo ">> formatting code"
	@$(GO) fmt $(pkgs)

vet:
	@echo ">> vetting code"
	@$(GO) vet $(pkgs)

build-all: assets build

build: promu
	@echo ">> building binaries"
	@$(PROMU) build --prefix $(PREFIX) $(BINARIES)

tarball: promu
	@echo ">> building release tarball"
	@$(PROMU) tarball --prefix $(PREFIX) $(BIN_DIR)

docker:
	@echo ">> building docker image"
	@docker build -t "$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)" .

assets:
	@echo ">> writing assets"
	@$(GO) get github.com/go-bindata/go-bindata/...
	@$(GO) install github.com/go-bindata/go-bindata/...
	# Using "-mode 420" and "-modtime 1" to make assets make target deterministic.
	# It sets all file permissions and time stamps to 420 and 1
	@go-bindata $(bindata_flags) -mode 420 -modtime 1 -pkg ui -o ui/bindata.go -prefix 'ui/' ui/templates/... ui/static/...
	@$(GO) fmt ./ui

promu:
	@GOOS=$(shell uname -s | tr A-Z a-z) \
	GOARCH=$(subst x86_64,amd64,$(patsubst i%86,386,$(shell uname -m))) \
	$(GO) get github.com/prometheus/promu
	$(GO) install github.com/prometheus/promu

go-build-graphite-remote-adapter:
	@GOOS=linux \
	GOARCH=amd64 \
	$(GO) build -o .build/linux-amd64/graphite-remote-adapter \
	-buildvcs=false -ldflags="-X 'github.com/prometheus/common/version.Version=$(shell cat VERSION)' \
	-X 'github.com/prometheus/common/version.Revision=$(shell git rev-parse HEAD)' \
	-X 'github.com/prometheus/common/version.Branch=master' \
	-X 'github.com/prometheus/common/version.BuildUser=github' \
	-X 'github.com/prometheus/common/version.BuildDate=$(shell date +"%Y%m%d-%H:%M:%S")' \
	-extldflags=-static" \
	-a -tags netgo github.com/criteo/graphite-remote-adapter/cmd/graphite-remote-adapter

go-build-ratool:
	@GOOS=linux \
	GOARCH=amd64 \
	$(GO) build -o .build/linux-amd64/ratool \
	-buildvcs=false -ldflags="-X 'github.com/prometheus/common/version.Version=$(shell cat VERSION)' \
	-X 'github.com/prometheus/common/version.Revision=$(shell git rev-parse HEAD)' \
	-X 'github.com/prometheus/common/version.Branch=master' \
	-X 'github.com/prometheus/common/version.BuildUser=github' \
	-X 'github.com/prometheus/common/version.BuildDate=$(shell date +"%Y%m%d-%H:%M:%S")' \
	-extldflags=-static" \
	-a -tags netgo github.com/criteo/graphite-remote-adapter/cmd/ratool

test-version:
	.build/linux-amd64/graphite-remote-adapter --version

package:
	@mkdir .tarballs
	@tar -czvf .tarballs/graphite-remote-adapter-$(shell cat VERSION).linux-amd64.tar.gz --directory=.build/linux-amd64 graphite-remote-adapter
	@tar -czvf .tarballs/ratool-$(shell cat VERSION).linux-amd64.tar.gz --directory=.build/linux-amd64 ratool

clean:
	[ -f ui/bindata.go ] && rm ui/bindata.go

mod-tidy:
	@echo ">> tidy go mods"
	@$(GO) mod tidy

proto:


.PHONY: all style format build test vet assets tarball docker promu proto
