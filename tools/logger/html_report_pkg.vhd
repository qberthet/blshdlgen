-------------------------------------------------------------------------------
--    Copyright 2018 HES-SO HEIG-VD REDS
--    All Rights Reserved Worldwide
--
--    Licensed under the Apache License, Version 2.0 (the "License");
--    you may not use this file except in compliance with the License.
--    You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
--    Unless required by applicable law or agreed to in writing, software
--    distributed under the License is distributed on an "AS IS" BASIS,
--    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--    See the License for the specific language governing permissions and
--    limitations under the License.
-------------------------------------------------------------------------------
--
-- File        : heml_report_pkg.vhd
-- Description : This package offers a simple way to generate an HTML report
--               for a VHDL simulation. The generated file allows to view
--               messages in a browser and to choose what severity level to
--               display.
--
-- Author      : Yann Thoma
-- Team        : REDS institute
-- Date        : 07.03.18
--
--
--| Modifications |------------------------------------------------------------
-- Ver  Date      Who   Description
-- 1.0  07.03.18  YTA   First version
-- 1.1  17.03.18  QB    Add reporting of error and warning count
-- 1.2  25.01.19  QB    Report cosmetic improvement
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

package html_report_pkg is

    -- Adds a message with a certain severity level. The input message is of
    -- type Line
    procedure html_write(file f: text;
                         l:inout line;
                         sev:severity_level);

    -- Adds a message with a certain severity level. The input message is of
    -- type string
    procedure html_report(file f: text;
                          message : in string;
                          sev:severity_level);

    -- This procedure has to be called at the beginning, in order to ensure
    -- correct HTML tags
    procedure html_start(file f: text;
                         l:inout line;
                         date: in string);

    -- This procedure has to be called at the end of the simulation, in order
    -- to ensure correct ending of HTML tags
    -- Total error and warning can be provided to be incorporated at the end
    -- of the page
    procedure html_end(file f:text;
                       warning: in integer := -1;
                       error: in integer := -1);

end html_report_pkg;


package body html_report_pkg is

    procedure html_report(file f: text;message : in string;sev:severity_level) is
        variable tmp_line : line;
    begin
        write(tmp_line,message);
        html_write(f,tmp_line,sev);
    end html_report;

    procedure html_write(file f: text;l:inout line;sev:severity_level) is
        variable tmp_line: line;
    begin
        case sev is
        when NOTE =>
            write(tmp_line,string'("<tr class='note'><td>Note</td><td>"));
            write(tmp_line,now);
            write(tmp_line,string'("</td><td>"));
        when WARNING =>
            write(tmp_line,string'("<tr class='warning'><td>Warning</td><td>"));
            write(tmp_line,now);
            write(tmp_line,string'("</td><td>"));

        when ERROR =>
            write(tmp_line,string'("<tr class='error'><td>Error</td><td>"));
            write(tmp_line,now);
            write(tmp_line,string'("</td><td>"));

        when FAILURE =>
            write(tmp_line,string'("<tr class='failure'><td>Failure</td><td>"));
            write(tmp_line,now);
            write(tmp_line,string'("</td><td>"));

        end case;
        writeline(f,tmp_line);
        writeline(f,l);
        write(l,string'("</td></tr>"));
        writeline(f,l);

    end html_write;

    procedure html_start(file f: text;l:inout line;date: in string) is
        variable tmp_line: line;
    begin
        write(tmp_line,string'("<!doctype html>"));
        write(tmp_line,string'("<html lang=""en"">"));
        write(tmp_line,string'("<head>"));
        write(tmp_line,string'("<meta charset=""utf-8"">"));
        write(tmp_line,string'("<link rel=""stylesheet"" href=""https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.1.1/css/bootstrap.css"">"));
        write(tmp_line,string'("<script src=""https://code.jquery.com/jquery-3.3.1.js""></script>"));
        write(tmp_line,string'("<title>"));
        write(tmp_line,string'("Testbench report"));
        write(tmp_line,string'("</title>"));
        write(tmp_line,string'("<style>"));
        write(tmp_line,string'("    <!--"));
        write(tmp_line,string'("    body { margin: 0; font-family: Arial; font-size: 12pt; padding: 20px; }"));
        write(tmp_line,string'("    tbody { margin: 0; font-family: Arial; font-size: 11pt; padding: 20px; }"));
        write(tmp_line,string'("    thead { font-weight: bold; }"));
        write(tmp_line,string'("    .table td { padding: 5px; }"));
        write(tmp_line,string'("    .warning { background-color: rgb(255,255,160) !important; }"));
        write(tmp_line,string'("    .error { background-color: rgb(255,160,160) !important; }"));
        write(tmp_line,string'("    .failure { background-color: rgb(255,80,80) !important; }"));
        write(tmp_line,string'("    -->"));
        write(tmp_line,string'("</style>"));
        write(tmp_line,string'("</head>"));
        write(tmp_line,string'("<body>"));
        write(tmp_line,string'("<h1>"));
        writeline(f,tmp_line);
        writeline(f,l);
        write(tmp_line,string'("</h1>"));
        write(tmp_line,string'("<p>"));
        write(tmp_line,string'("    Show/Hide :"));
        write(tmp_line,string'("    <input id=""note_button"" type=""button"" value=""Note"" name=""showNote"" onclick=""$('.note').toggle();"">"));
        write(tmp_line,string'("    <input id=""warning_button"" type=""button"" value=""Warning"" name=""showWarning"" onclick=""$('.warning').toggle();"">"));
        write(tmp_line,string'("    <input id=""error_button"" type=""button"" value=""Error"" name=""showError"" onclick=""$('.error').toggle();"">"));
        write(tmp_line,string'("    <input id=""failure_button"" type=""button"" value=""Failure"" name=""showFailure"" onclick=""$('.failure').toggle();"">"));
        write(tmp_line,string'("</p>"));
        write(tmp_line,string'("<table id=""results"" class=""table table-bordered table-hover"">"));
        write(tmp_line,string'("    <thead>"));
        write(tmp_line,string'("    <tr>"));
        write(tmp_line,string'("        <td>Type</td>"));
        write(tmp_line,string'("        <td>Time</td>"));
        write(tmp_line,string'("        <td>Description</td>"));
        write(tmp_line,string'("    </tr>"));
        write(tmp_line,string'("    </thead>"));
        write(tmp_line,string'("    <tbody>"));
        writeline(f,tmp_line);
    end html_start;

    procedure html_end(file f:text;
                       warning: in integer := -1;
                       error: in integer := -1) is
        variable tmp_line: line;
    begin
        write(tmp_line,string'("    </tbody>"));
        write(tmp_line,string'("</table>" & CR ));
        writeline(f,tmp_line);
        if (warning >= 0) or (error >= 0) then
            write(tmp_line,string'("<h2>Final report:</h2>" & CR & "<table>"));
            writeline(f,tmp_line);
            if (warning >= 0) then
                write(tmp_line, "<tr><td>Total warning:</td><td>" &
                                integer'image(warning) & "</td></tr>"& CR);
                writeline(f,tmp_line);
            end if;
            if (error >= 0) then
                write(tmp_line, "<tr><td>Total error:</td><td>" &
                                integer'image(error) & "</td></tr>"& CR);
                writeline(f,tmp_line);
            end if;
            write(tmp_line,string'("</table>"));
            writeline(f,tmp_line);
        end if;
        write(tmp_line,string'("</body></html>"));
        writeline(f,tmp_line);
    end html_end;

end html_report_pkg;
