export_diagrams:
	docker run --rm -ti -v $(PWD):/data rlespinasse/drawio-export:v4.24.0 -f svg --scale 5 --enable-plugins -o /data/assets/images/diagrams /data/diagram_sources/

dev:
	bundle exec jekyll serve
