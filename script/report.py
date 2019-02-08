
import datetime
import time

path = cwd + "/work"
pattern = "*_tb.html"
result = []

def html_start(title, date):
    tmp_line =  ""
    tmp_line += "<!doctype html>\n"
    tmp_line += "<html lang=\"en\">\n"
    tmp_line += "<head>\n"
    tmp_line += "<meta charset=\"utf-8\">\n"
    tmp_line += "<link rel=\"stylesheet\" type=\"text/css\" href=\"https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.1.1/css/bootstrap.css\">\n"
    tmp_line += "<link rel=\"stylesheet\" type=\"text/css\" href=\"https://cdn.datatables.net/1.10.19/css/dataTables.bootstrap4.min.css\">\n"
    tmp_line += "<script src=\"https://code.jquery.com/jquery-3.3.1.js\"></script>\n"
    tmp_line += "<script src=\"https://cdn.datatables.net/1.10.19/js/jquery.dataTables.min.js\"></script>\n"
    tmp_line += "<script src=\"https://cdn.datatables.net/1.10.19/js/dataTables.bootstrap4.min.js\"></script>\n"
    tmp_line += "<script>\n"
    tmp_line += "$(document).ready(function() {\n"
    tmp_line += "$('#results').DataTable();\n"
    tmp_line += "});\n"
    tmp_line += "</script>\n"
    tmp_line += "<title>"
    tmp_line += title
    tmp_line += "</title>\n"
    tmp_line += "<style>\n"
    tmp_line += "<!--\n"
    tmp_line += "body { margin: 0; padding: 0; font-family: Arial; font-size: 12pt; padding: 20px; }\n"
    tmp_line += "tbody { margin: 0; padding: 0; font-family: Arial; font-size: 11pt; padding: 20px; }\n"
    tmp_line += "thead { font-weight: bold; }\n"
    tmp_line += "table.dataTable td { padding: 5px; }\n"
    tmp_line += ".warning { background-color: rgb(255,255,160) !important; }\n"
    tmp_line += ".error { background-color: rgb(255,160,160) !important; }\n"
    tmp_line += ".failure { background-color: rgb(255,80,80) !important; }\n"
    tmp_line += "-->\n"
    tmp_line += "</style>\n"
    tmp_line += "</head>\n"
    tmp_line += "<body>\n"
    tmp_line += "<h1>"
    tmp_line += title
    tmp_line += "</h1>\n"
    tmp_line += "<p>Report aggregation generated on "
    tmp_line += date
    tmp_line += "</p>\n"
    tmp_line += "<table id=\"results\" class=\"table table-bordered table-hover\">\n"
    tmp_line += "<thead>\n"
    tmp_line += "<tr>\n"
    tmp_line += "<td>Domain Parameters</td>\n"
    tmp_line += "<td>Entity Name</td>\n"
    tmp_line += "<td>Test Status</td>\n"
    tmp_line += "<td>Message</td>\n"
    tmp_line += "<td>Date</td>\n"
    tmp_line += "<td>Log File</td>\n"
    tmp_line += "</tr>\n"
    tmp_line += "</thead>\n"
    tmp_line += "<tbody>\n"
    return tmp_line

def html_write(data, severity_level = "NOTE"):
        tmp_line = ""
        if severity_level == "WARNING":
            tmp_line += "<tr class='warning'>"
        elif severity_level == "ERROR":
            tmp_line += "<tr class='error'>"
        elif severity_level == "FAILURE":
            tmp_line += "<tr class='failure'>"
        else:
            tmp_line += "<tr>"
        tmp_line += data
        tmp_line += "</tr>\n"
        return tmp_line

def html_end():
    tmp_line =  ""
    tmp_line += "</tbody></table></body></html>\n"
    return tmp_line

def file_contains(filepath, str):
    return str in open( URL ).read()

def file_moddate(path_to_file):
    fd = os.path.getmtime(path_to_file)
    tim = time.localtime(fd)
    return time.strftime("%Y/%d/%m %H:%M:%S", tim)

filedate = "error"

# FIXME split this mess into various functions/methods
if os.path.exists(path):
    # Start report aggregation
    now = datetime.datetime.now()
    data =  html_start("Overview of testbench reports:", str(now))
    dirs = os.listdir(path)
    for name in sorted(dirs):
        if os.path.isdir(path + "/" + name):
            # Iterate over all folder, should be domain_param
            #data += html_write_sep( name)
            dirs2 = os.listdir(path + "/" + name)
            for name2 in sorted(dirs2):
                # Iterate over all testbench files
                if name2.endswith("_tb.vhd"):
                    URL =  path + "/" + name + "/" + name2[:-4] + ".html"
                    # Check if HTML report exist
                    entity_name = name2[:-7]
                    if os.path.exists(URL):
                        filedate = file_moddate(URL)
                        relative_URL = os.path.relpath(URL, path)
                        if file_contains(URL, "<tr class='failure'>"):
                            data += html_write( "<td>" + name + "</td><td>" + entity_name + "</td><td>FAILURE</td><td>Testbench failed</td><td>" + filedate + "</td><td><a href=\"" + relative_URL + "\"> tb log file </a></td>", "FAILURE")
                        elif file_contains(URL, "<tr class='error'>"):
                            data += html_write( "<td>" + name + "</td><td>" + entity_name + "</td><td>ERROR</td><td>Testbench finished with error</td><td>" + filedate + "</td><td><a href=\"" + relative_URL + "\"> tb log file </a></td>", "ERROR")
                        elif file_contains(URL, "<tr class='warning'>"):
                            data += html_write( "<td>" + name + "</td><td>" + entity_name + "</td><td>WARNING</td><td>Testbench finished with warning</td><td>" + filedate + "</td><td><a href=\"" + relative_URL + "\"> tb log file </a></td>", "WARNING")
                        else:
                            data += html_write( "<td>" + name + "</td><td>" + entity_name + "</td><td>OK</td><td>Testbench finished successfully</td><td>" + filedate + "</td><td><a href=\"" + relative_URL + "\"> tb log file </a></td>", "NOTE")
                    elif os.path.exists(URL[:-5]):
                        # If there is no HTML report, look for xvhdl.log and elaborate.log inside project folder
                        xvhdl_log = ""
                        elaborate_log = ""
                        for root3, dirs3, files3 in os.walk(URL[:-5]):
                            for name3 in files3:
                                if fnmatch.fnmatch(name3, "*xvhdl.log" ):
                                    xvhdl_log = os.path.normpath(root3 + "/xvhdl.log")
                        for root3, dirs3, files3 in os.walk(URL[:-5]):
                            for name3 in files3:
                                if fnmatch.fnmatch(name3, "*elaborate.log" ):
                                    elaborate_log = os.path.normpath(root3 + "/elaborate.log")
                        # If elaborate.log is present, the compilation should be successfull..
                        if elaborate_log != "":
                            filedate = file_moddate(elaborate_log)
                            data += html_write( "<td>" + name + "</td><td>" + entity_name + "</td><td>ERROR</td><td>Testbench elaboration failed</td><td>" + filedate + "</td><td><a href=\"" +  os.path.relpath(elaborate_log, path) + "\"> elaborate.log </a></td>", "ERROR")
                        # If not, report xvhdl.log
                        elif xvhdl_log != "":
                            filedate = file_moddate(xvhdl_log)
                            data += html_write( "<td>" + name + "</td><td>" + entity_name + "</td><td>ERROR</td><td>Testbench compilation failed</td><td>" + filedate + "</td><td><a href=\"" + os.path.relpath(xvhdl_log, path) + "\"> xvhdl.log </a></td>", "ERROR")
                        # if no log file found, report
                        else:
                            dt = datetime.datetime.now()
                            filedate = dt.strftime("%Y/%d/%m %H:%M:%S")
                            data += html_write( "<td>" + name + "</td><td>" + entity_name + "</td><td>ERROR</td><td>xvhdl.log does not exist</td><td>" + filedate + "</td><td><a href=\"" + os.path.relpath(URL[:-5], path) + "\"> project folder </a></td>", "ERROR")
                    # Project folder not found, report
                    else:
                        dt = datetime.datetime.now()
                        filedate = dt.strftime("%Y/%d/%m %H:%M:%S")
                        data += html_write( "<td>" + name + "</td><td>" + entity_name + "</td><td>ERROR</td><td>Testbench project not created</td><td>" + filedate + "</td><td></td>", "ERROR")
    data += html_end()
    filename = path + "/tb_report.html"
    new_file = open( filename, 'w' )
    new_file.write( data )
    new_file.close()
    print "  Created: " + filename
else:
    print "  Testbench folder does not exist, no report created"


