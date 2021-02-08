app_id := myapp
dist_dir := ./dist
build_dir = $(dist_dir)/$(app_id)
app_dirs = $(shell find ./app -type d -not -path "./app/local")
app_files = $(shell find ./app -type f -not -path "./app/local/*" -not -path "./app/metadata/local.meta" | sed 's: :\\ :g')

# Throw an error if no target is specified
.PHONY: error
error:
	@echo "Please choose a target... you can list them by running \"make help\""
	@exit 2

# Manage npm packages
node_modules: package.json package-lock.json
	@npm ci
	@touch package-lock.json
	@touch node_modules

# Targets to manage app obfuscation and packaging
$(build_dir): node_modules $(app_dirs) $(app_files)
	$(MAKE) clean
	mkdir -p $(dist_dir)
	cp -a ./app "$(build_dir)"
	rm -rf "$(build_dir)/local" "$(build_dir)/metadata/local.meta"
	find "$(build_dir)/appserver/static" -type f -name "*.js" \
		-not -path "$(build_dir)/appserver/static/components/jsrsasign-*/*" \
		-exec npx javascript-obfuscator "{}" --output "{}" \;
	@touch $(build_dir)

$(dist_dir)/$(app_id)-*.tar.gz: $(build_dir)
	@tox -e package

.PHONY: package
package: $(dist_dir)/$(app_id)-*.tar.gz  ## Obfuscate code and build tarball

.PHONY: inspect
inspect: $(dist_dir)/$(app_id)-*.tar.gz ## Run Splunk AppInspect
	@tox -e appinspect $(dist_dir)/$(app_id)-*.tar.gz

.PHONY: inspect-precert
inspect-precert: $(dist_dir)/$(app_id)-*.tar.gz  ## Run Splunk AppInspect in precert (verbose) mode
	@tox -e appinspect $(dist_dir)/$(app_id)-*.tar.gz -- --mode precert

.PHONY: inspect-cloud
inspect-cloud: $(dist_dir)/$(app_id)-*.tar.gz  ## Run Splunk AppInspect in precert (verbose) mode
	@tox -e appinspect $(dist_dir)/$(app_id)-*.tar.gz -- --included-tags self-service --included-tags cloud

.PHONY: inspect-cloud-precert
inspect-cloud-precert: $(dist_dir)/$(app_id)-*.tar.gz  ## Run Splunk AppInspect in precert (verbose) mode
	@tox -e appinspect $(dist_dir)/$(app_id)-*.tar.gz -- --mode precert --included-tags self-service --included-tags cloud

.PHONY: lint
lint: node_modules  ## Lint code via StandardJS (plus semicolons)
	@npx semistandard

.PHONY: clean
clean:  ## Remove build artifacts and Python bytecode/caches
	rm -rf $(dist_dir)
	find ./app/bin -type f -name "*.py[cod]" -delete
	find ./app/bin -type d -name "__pycache__" -delete

# Display help for any target with a comment on the same line starting with '## '
.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
