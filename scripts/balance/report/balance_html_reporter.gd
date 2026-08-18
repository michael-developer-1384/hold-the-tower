extends RefCounted

## Fill the offline HTML template. Charts read the embedded JSON only.


static func render(report: Dictionary) -> String:
	var html := FileAccess.get_file_as_string("res://assets/dev/balance_report/report_template.html")
	var css := FileAccess.get_file_as_string("res://assets/dev/balance_report/report.css")
	var js := FileAccess.get_file_as_string("res://assets/dev/balance_report/report.js")
	var payload := JSON.stringify(report)
	html = html.replace("/*__REPORT_CSS__*/", css)
	html = html.replace("/*__REPORT_JS__*/", js)
	html = html.replace("/*__REPORT_JSON__*/", payload)
	return html
