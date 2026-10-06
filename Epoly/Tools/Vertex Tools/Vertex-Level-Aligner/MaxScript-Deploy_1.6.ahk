; Generic MaxScript deployment helper.
; Script version 1.7.
; Target: AutoHotkey 1.1.36.02.


#NoEnv
#SingleInstance Force
SetBatchLines, -1


maxscript_deploy_script_version := "1.7"


if (A_Args.MaxIndex() && (A_Args[1] = "--test"))
{
    test_passed := testMaxScriptDeploy()
    exit_code := test_passed ? 0 : 1
    ExitApp, %exit_code%
}


deployMaxScriptProject(A_ScriptDir)
ExitApp




; Deploys the current MaxScript project into its releases subfolder.
; Only .ms and .mcr files are copied, with their relative folders preserved.
deployMaxScriptProject(source_dir)
{
    project_name := getProjectName(source_dir)
    tool_version := getProjectVersion(source_dir)


    if (tool_version = "")
    {
        MsgBox, 16, MaxScript Deploy, Could not find a Project version value in any .ms or .mcr file.`n`nSource:`n%source_dir%
        return false
    }


    destination_dir := getDeployDestination(source_dir, tool_version)


    if (destination_dir = "")
    {
        MsgBox, 16, MaxScript Deploy, Could not build the deployment folder path.
        return false
    }


    if (FileExist(destination_dir))
    {
        MsgBox, 48, MaxScript Deploy, Deployment already exists:`n`n%destination_dir%
        return false
    }


    if (!copyMaxScriptFiles(source_dir, destination_dir))
    {
        MsgBox, 16, MaxScript Deploy, Deployment failed.`n`nSource:`n%source_dir%`n`nDestination:`n%destination_dir%
        return false
    }


    MsgBox, 64, MaxScript Deploy, Deployed %project_name% %tool_version%:`n`n%destination_dir%
    return true
}




; Returns the project folder name for display only.
; The deploy logic does not depend on this name.
getProjectName(source_dir)
{
    clean_source_dir := RTrim(source_dir, "\/")
    SplitPath, clean_source_dir, project_name


    if (project_name = "")
        return "MaxScript project"


    return project_name
}




; Reads the shared project version from generic .ms or .mcr source files.
; Root scripts are preferred, then _Versions, then all remaining project subfolders.
getProjectVersion(source_dir)
{
    version := getHighestProjectVersionInDirectory(source_dir, false)


    if (version != "")
        return version


    versions_dir := source_dir . "\_Versions"


    if (FileExist(versions_dir))
    {
        version := getHighestProjectVersionInDirectory(versions_dir, true)


        if (version != "")
            return version
    }


    return getHighestProjectVersionInDirectory(source_dir, true)
}




; Returns the highest Project version found in .ms or .mcr files in one directory scope.
; The scan may be root-only or recursive depending on recursive.
getHighestProjectVersionInDirectory(source_dir, recursive)
{
    ms_version := findHighestProjectVersionInFiles(source_dir, "*.ms", recursive)
    mcr_version := findHighestProjectVersionInFiles(source_dir, "*.mcr", recursive)


    if (isProjectVersionHigher(ms_version, mcr_version))
        return ms_version


    return mcr_version
}




; Finds the highest shared project version in files matching one MaxScript file mask.
; Supports prose headers plus project_version / epoly_tools_project_version assignments used by current repositories.
findHighestProjectVersionInFiles(source_dir, file_mask, recursive)
{
    loop_mode := recursive ? "FR" : "F"
    highest_version := ""


    Loop, Files, % source_dir . "\" . file_mask, %loop_mode%
    {
        file_path := A_LoopFileFullPath


        if (isExcludedSourcePath(source_dir, file_path))
            continue


        Loop, Read, %file_path%
        {
            if RegExMatch(A_LoopReadLine, "i)(?:Project\s+version\s*[:=]?|\bproject_version\s*=|\bepoly_tools_project_version\s*=)\s*([0-9]+(?:\.[0-9]+)+)", match)
            {
                if (isProjectVersionHigher(match1, highest_version))
                    highest_version := match1
            }
        }
    }


    return highest_version
}




; Compares dotted numeric Project versions such as 1.9 and 1.10.
; Empty candidate versions are never considered higher.
isProjectVersionHigher(candidate_version, current_version)
{
    if (candidate_version = "")
        return false


    if (current_version = "")
        return true


    candidate_parts := StrSplit(candidate_version, ".")
    current_parts := StrSplit(current_version, ".")
    max_parts := candidate_parts.MaxIndex()


    if (current_parts.MaxIndex() > max_parts)
        max_parts := current_parts.MaxIndex()


    Loop, %max_parts%
    {
        candidate_part := (A_Index <= candidate_parts.MaxIndex()) ? (candidate_parts[A_Index] + 0) : 0
        current_part := (A_Index <= current_parts.MaxIndex()) ? (current_parts[A_Index] + 0) : 0


        if (candidate_part > current_part)
            return true


        if (candidate_part < current_part)
            return false
    }


    return false
}




; Returns true for repository internals, old releases, or temporary MaxScript files.
; Excluded sources cannot affect version detection or deployability checks.
isExcludedSourcePath(source_dir, file_path)
{
    source_prefix_length := StrLen(RTrim(source_dir, "\/")) + 2
    relative_path := SubStr(file_path, source_prefix_length)


    if RegExMatch(relative_path, "i)^(?:\.git|releases)(?:\\|$)")
        return true


    if RegExMatch(relative_path, "i)(?:^|\\)__tmp[^\\]*(?:\.ms|\.mcr)$")
        return true


    return false
}




; Builds the deployment path as <project>\releases\<tool-version>.
; The project and source script names do not affect the destination naming rule.
getDeployDestination(source_dir, tool_version)
{
    if ((source_dir = "") || (tool_version = ""))
        return ""


    return source_dir . "\releases\" . tool_version
}




; Copies only .ms and .mcr files while preserving their relative subfolders.
; .git, releases, and temporary __tmp scripts are excluded from deployment.
copyMaxScriptFiles(source_dir, destination_dir)
{
    if (!FileExist(source_dir))
        return false


    if (FileExist(destination_dir))
        return false


    if (!hasDeployableMaxScriptFiles(source_dir))
        return false


    robocopy_path := A_WinDir . "\System32\robocopy.exe"


    if (!FileExist(robocopy_path))
        return false


    SplitPath, destination_dir,, destination_parent


    if (destination_parent = "")
        return false


    if (!FileExist(destination_parent))
        FileCreateDir, %destination_parent%


    command := quoteArgument(robocopy_path)
    command .= " " . quoteArgument(source_dir)
    command .= " " . quoteArgument(destination_dir)
    command .= " *.ms *.mcr"
    command .= " /S /COPY:DAT /DCOPY:DAT /R:1 /W:1"
    command .= " /XD " . quoteArgument(source_dir . "\.git")
    command .= " " . quoteArgument(source_dir . "\releases")
    command .= " /XF " . quoteArgument("__tmp*.ms")
    command .= " " . quoteArgument("__tmp*.mcr")
    command .= " /NFL /NDL /NJH /NJS /NP"


    RunWait, %command%,, Hide UseErrorLevel
    robocopy_exit_code := ErrorLevel


    if (robocopy_exit_code = "ERROR")
        return false


    if (robocopy_exit_code >= 8)
        return false


    return FileExist(destination_dir) ? true : false
}




; Checks whether at least one deployable .ms or .mcr file exists outside excluded trees.
; This avoids creating an empty release folder.
hasDeployableMaxScriptFiles(source_dir)
{
    if (hasDeployableFileMask(source_dir, "*.ms"))
        return true


    return hasDeployableFileMask(source_dir, "*.mcr")
}




; Checks one file mask for a current deployable source file.
; Files below .git and releases are ignored.
hasDeployableFileMask(source_dir, file_mask)
{
    Loop, Files, % source_dir . "\" . file_mask, FR
    {
        if (!isExcludedSourcePath(source_dir, A_LoopFileFullPath))
            return true
    }


    return false
}




; Quotes one command-line argument for Windows paths containing spaces.
; The returned value includes the surrounding double quotes.
quoteArgument(value)
{
    return Chr(34) . value . Chr(34)
}




; Tests current assignment syntax, _Versions fallback data, deployment, and exclusions.
; Run with: MaxScript-Deploy.ahk --test
testMaxScriptDeploy()
{
    test_id := A_TickCount
    source_dir := A_Temp . "\MaxScriptDeployTest_" . test_id
    fallback_dir := A_Temp . "\MaxScriptDeployFallbackTest_" . test_id
    expected_version := "9.876"
    fallback_expected_version := "7.654"


    FileCreateDir, %source_dir%
    FileCreateDir, %source_dir%\_Versions
    FileCreateDir, %source_dir%\Scripts\Nested
    FileCreateDir, %source_dir%\Docs
    FileCreateDir, %source_dir%\.git
    FileCreateDir, %source_dir%\releases\8.765


    FileAppend, project_version = %expected_version%`,`r`n, %source_dir%\Completely-Different-Name.ms
    FileAppend, Project version: 8.765.`r`n, %source_dir%\_Versions\Old-Arbitrary-Name.ms
    FileAppend, Project version: 8.900.`r`n, %source_dir%\_Versions\Newest-Arbitrary-Name.mcr
    FileAppend, macroScript ArbitraryMacro`r`n(`r`n)`r`n, %source_dir%\Scripts\Nested\Another-Name.mcr
    FileAppend, Project version: 99.999.`r`n, %source_dir%\Docs\readme.txt
    FileAppend, should not deploy`r`n, %source_dir%\.gitignore
    FileAppend, Project version 1.111.`r`n, %source_dir%\.git\Ignored.ms
    FileAppend, Project version 88.888.`r`n, %source_dir%\releases\8.765\Old.ms
    FileAppend, project_version = 77.777`,`r`n, %source_dir%\__tmp_should_not_deploy.ms


    FileCreateDir, %fallback_dir%
    FileCreateDir, %fallback_dir%\_Versions
    FileAppend, no project version here`r`n, %fallback_dir%\Current-Without-Version.ms
    FileAppend, project_version = %fallback_expected_version%`,`r`n, %fallback_dir%\_Versions\Fallback-Version.ms


    parsed_version := getProjectVersion(source_dir)
    fallback_parsed_version := getProjectVersion(fallback_dir)
    destination_dir := getDeployDestination(source_dir, parsed_version)
    copied := copyMaxScriptFiles(source_dir, destination_dir)


    passed := true
    passed := passed && (parsed_version = expected_version)
    passed := passed && (fallback_parsed_version = fallback_expected_version)
    passed := passed && (destination_dir = source_dir . "\releases\" . expected_version)
    passed := passed && copied
    passed := passed && FileExist(destination_dir . "\Completely-Different-Name.ms")
    passed := passed && !FileExist(destination_dir . "\__tmp_should_not_deploy.ms")
    passed := passed && FileExist(destination_dir . "\_Versions\Old-Arbitrary-Name.ms")
    passed := passed && FileExist(destination_dir . "\_Versions\Newest-Arbitrary-Name.mcr")
    passed := passed && FileExist(destination_dir . "\Scripts\Nested\Another-Name.mcr")
    passed := passed && !FileExist(destination_dir . "\Docs\readme.txt")
    passed := passed && !FileExist(destination_dir . "\.gitignore")
    passed := passed && !FileExist(destination_dir . "\.git")
    passed := passed && !FileExist(destination_dir . "\releases")


    FileRemoveDir, %source_dir%, 1
    FileRemoveDir, %fallback_dir%, 1


    if (passed)
        MsgBox, 64, MaxScript Deploy Test, PASS - current project-version syntax, _Versions fallback, and temporary-file exclusion are verified.
    else
        MsgBox, 16, MaxScript Deploy Test, FAIL - one or more deployment checks failed.


    return passed
}
