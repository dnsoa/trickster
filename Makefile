DEFAULT: build

GO           ?= go
GOFMT        ?= $(GO)fmt
FIRST_GOPATH := $(firstword $(subst :, ,$(shell $(GO) env GOPATH)))
DEP          := $(FIRST_GOPATH)/bin/dep

PROGVER = $(shell grep 'applicationVersion = ' main.go | awk '{print $$3}' | sed -e 's/\"//g')

.PHONY: $(DEP)
$(DEP):
	GOOS= GOARCH= $(GO) get -u github.com/golang/dep/cmd/dep

.PHONY: deps
deps: $(DEP)
	$(DEP) ensure

build: deps
	go build -o ${GOPATH}/bin/trickster

release: build release-artifacts docker docker-release

release-artifacts:
	GOOS=darwin GOARCH=amd64 go build -o ./OPATH/trickster-$(PROGVER).darwin-amd64 && gzip -f ./OPATH/trickster-$(PROGVER).darwin-amd64
	GOOS=linux  GOARCH=amd64 go build -o ./OPATH/trickster-$(PROGVER).linux-amd64  && gzip -f ./OPATH/trickster-$(PROGVER).linux-amd64

helm-local:
	kubectl config use-context minikube --namespace=trickster
	kubectl scale --replicas=0 deployment/dev-trickster -n trickster
	eval $$(minikube docker-env) \
		&& docker build -f deploy/Dockerfile -t trickster:dev .
	kubectl set image deployment/dev-trickster trickster=trickster:dev -n trickster
	kubectl scale --replicas=1 deployment/dev-trickster -n trickster

kube-local:
	kubectl config use-context minikube
	kubectl scale --replicas=0 deployment/trickster
	eval $$(minikube docker-env) \
		&& docker build -f deploy/Dockerfile -t trickster:dev .
	kubectl set image deployment/trickster trickster=trickster:dev
	kubectl scale --replicas=1 deployment/trickster

docker:
	docker build -f ./deploy/Dockerfile -t trickster:$(PROGVER) .

docker-release:
	docker tag trickster:$(PROGVER) tricksterio/trickster:$(PROGVER)
	docker tag tricksterio/trickster:$(PROGVER) tricksterio/trickster:latest

.PHONY: style
style:
	! gofmt -d $$(find . -path ./vendor -prune -o -name '*.go' -print) | grep '^'

.PHONY: test
test: deps
	go test -o ${GOPATH}/bin/trickster -v ./...

.PHONY: test-cover
test-cover: deps
	go test -o ${GOPATH}/bin/trickster -coverprofile=cover.out ./...
	go tool cover -html=cover.out

clean:
	rm ${GOPATH}/bin/trickster

.PHONY: build helm-local kube-local docker docker-release clean
