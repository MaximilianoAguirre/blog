hydrate_images:
	docker run -ti -v $(PWD):/data rlespinasse/drawio-export -f svg -o /data/assets/images/diagrams /data/diagram_sources/

dev:
	bundle exec jekyll serve
