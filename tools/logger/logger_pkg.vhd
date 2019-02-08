-------------------------------------------------------------------------------
--    Copyright 2018 Quentin Berthet
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
-- File        : logger_pkg.vhd
-- Description : This package offers a simple way to log error at various
--               severity levels. They can also be logged to HTML report thanks
--               to htmp_report_pkg.vhd provided by YTA.
--
-- Author      : Quentin Berthet
-- Team        : VSN 2018
-- Date        : 15.03.18
--
--| Modifications |------------------------------------------------------------
-- Ver  Date      Who   Description
-- 1.0  24.02.18  QB    First version
-- 1.1  15.03.18  QB    Added HTML report (No time support yet)
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library work;
use work.html_report_pkg.all;

package logger_pkg is

    type logger_t is protected

        -- Set current severity level
        -- Event with lower severity level will not be logged to console or log
        -- file, but they will still be present in HTML report if enabled
        procedure set_log_level(new_level : severity_level);

        -- Enable file logging
        -- The filename can be specified as a parameter, or will be
        -- "default.log" if none provided.
        -- Can be called again to change the current log file.
        procedure set_log_file(file_name : string := "default.log");

        -- Enable HTML report file creation
        -- The filename can be specified as a parameter, or will be
        -- "default.html" if none provided.
        -- All secverity will be logged to HTML report file
        -- Can be called again to change the current log file.
        procedure set_html_report_file(file_name : string := "default.html";
                                       report_title : string := "Simulation report";
                                       date_time_str : string := "UNKOWN");

        -- Enable or disable simulation time logging in log file (Default off)
        procedure set_log_file_time(enabled : boolean := true);

        -- Enable or disable reporting to console (Default on)
        procedure set_log_report_console(enabled : boolean := true);

        -- Log a message with parametric severity level
        procedure log(message : string := "";
                      level : severity_level := NOTE);

        -- Log a note, with optional message string
        procedure log_note(message : string := "");

        -- Log a warning, with optional message string
        procedure log_warning(message : string := "");

        -- Log an error, with optional message string
        procedure log_error(message : string := "");

        -- Log a failure, with optional message string
        procedure log_failure(message : string := "");

        -- Print simulation final report to console an log file if open
        -- Need to be called to cleanlly close log file and HTML report
        procedure final_report;

        -- signal date_time_str : string (1 to 28);

    end protected logger_t;

end logger_pkg;

package body logger_pkg is

    type logger_t is protected body

        variable log_level : severity_level := NOTE;

        variable nb_warnings : natural := 0;
        variable nb_errors : natural := 0;

        file log_file: text;

        file html_report_file: text;

        --date_time_str(1 to 9) <= " UNKNOWN ";
        --date_time_str(10 to date_time_str'high) <= (others => ' ');

        variable log_file_is_open: boolean := false;
        variable log_html_report_file_is_open: boolean := false;
        variable log_file_time: boolean := false;
        variable log_report_console: boolean := true;

        -- Set minimal reported log level
        procedure set_log_level(new_level : severity_level) is
        begin
            log_level := new_level;
        end set_log_level;

        -- Set log file name
        -- If used, logging will be done in file instead of console
        -- Can be called again to change log file
        procedure set_log_file(file_name : string := "default.log") is
        begin
            if log_file_is_open then
                file_close(log_file);
                log_file_is_open := false;
            end if;

            file_open(log_file, file_name, WRITE_MODE);
            log_file_is_open := true;
        end set_log_file;

        procedure set_html_report_file(file_name : string := "default.html";
                                       report_title : string := "Simulation report";
                                       date_time_str : string := "UNKOWN") is
            variable l: line;
        begin
            if log_html_report_file_is_open then
                html_end(html_report_file);
                file_close(html_report_file);
                log_html_report_file_is_open := false;
            end if;

            file_open(html_report_file, file_name, WRITE_MODE);
            log_html_report_file_is_open := true;

            write(l,report_title);
            html_start(html_report_file, l, date_time_str);
        end;

        -- Enable or disable printing of simulation time in log file
        procedure set_log_file_time(enabled : boolean := true) is
        begin
            log_file_time := enabled;
        end;

        -- Enable or disable reporting to console
        procedure set_log_report_console(enabled : boolean := true) is
        begin
            log_report_console := enabled;
        end;

        -- Log helper
        procedure log(message: string := ""; level: severity_level := NOTE) is
            variable log_line: Line;
        begin
            -- Update counters
            case level is
                when WARNING => nb_warnings := nb_warnings + 1;
                when ERROR   => nb_errors   := nb_errors   + 1;
                when others  => null;
            end case;

            -- Filter by log_level
            if level >= log_level then
                if log_file_is_open then -- Print log in file

                    -- If enabled, print simulation time
                    if log_file_time then
                        write(log_line, string'(time'image(now)) & " ");
                    end if;

                    -- Print severity level
                    case level is
                        when NOTE    => write(log_line, string'("NOTE: "));
                        when WARNING => write(log_line, string'("WARN: "));
                        when ERROR   => write(log_line, string'("ERR : "));
                        when FAILURE => write(log_line, string'("FAIL: "));
                    end case;

                    -- Print message
                    write(log_line, message);
                    writeline(log_file,log_line);

                end if;

                if log_html_report_file_is_open then
                    html_report(html_report_file, message, level);
                end if;

                if log_report_console then -- Report to console
                    report message severity level;
                end if;

            end if;
        end log;

        -- Wrappers
        procedure log_note(message: string := "")    is begin
            log(message, NOTE);    end log_note;

        procedure log_warning(message: string := "") is begin
            log(message, WARNING); end log_warning;

        procedure log_error(message: string := "")   is begin
            log(message, ERROR);   end log_error;

        procedure log_failure(message: string := "") is begin
            log(message, FAILURE); end log_failure;

        procedure final_report is
            variable report_line: Line;
        begin
            report "Final report:";
            report "  Nb errors = " & integer'image(nb_errors);
            report "  Nb warnings = " & integer'image(nb_warnings);
            if log_file_is_open then
                write(report_line, string'("Final report:"));
                writeline(log_file,report_line);
                write(report_line, string'("  Nb errors = " &
                                           integer'image(nb_errors)));
                writeline(log_file,report_line);
                write(report_line, string'("  Nb warnings = " &
                                           integer'image(nb_warnings)));
                writeline(log_file,report_line);
            end if;

            if log_file_is_open then
                file_close(log_file);
                log_file_is_open := false;
            end if;

            if log_html_report_file_is_open then
                html_end(html_report_file, nb_warnings, nb_errors);
                file_close(html_report_file);
                log_html_report_file_is_open := false;
            end if;
        end final_report;

    end protected body logger_t;

end logger_pkg;
