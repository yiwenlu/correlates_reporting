## report : verification report; must have results of tester and programmer available
report: verification_report.Rmd
	Rscript -e "rmarkdown::render('verification_report.Rmd')"

# type 'make help' to show all make commands
help: Makefile
	@sed -n 's/^##//p' $<
