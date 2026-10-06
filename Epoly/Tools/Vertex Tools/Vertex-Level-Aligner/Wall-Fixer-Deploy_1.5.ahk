; Generic MaxScript deployment helper.
; Script version 1.5.
; Target: AutoHotkey 1.1.36.02.


#NoEnv
#SingleInstance Force
SetBatchLines, -1


maxscript_deploy_script_version := "1.5"


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




; Reads Project version from any current .ms or .mcr source file.
; Root scripts are preferred; recursive lookup is used only when no root script contains it.
getProjectVersion(source_dir)
{
    version := findProjectVersionInFiles(source_dir, "*.ms", false)


    if (version != "")
        return version


    version := findProjectVersionInFiles(source_dir, "*.mcr", false)


    if (version != "")
        return version


    version := findProjectVersionInFiles(source_dir, "*.ms", true)


    if (version != "")
        return version


    return findProjectVersionInFiles(source_dir, "*.mcr", true)
}




; Finds the first Project version header in files matching one MaxScript file mask.
; Expected examples: Project version 1.23 or Project version: 1.23.4.
findProjectVersionInFiles(source_dir, file_mask, recursive)
{
    loop_mode := recursive ? "FR" : "F"


    Loop, Files, % source_dir . "\" . file_mask, %loop_mode%
    {
        file_path := A_LoopFileFullPath


        if (isExcludedSourcePath(source_dir, file_path))
            continue


        Loop, Read, %file_path%
        {
            if RegExMatch(A_LoopReadLine, "i)Project\s+version\s*[:=]?\s*([0-9]+(?:\.[0-9]+)+)", match)
                return match1
        }
    }


    return ""
}




; Returns true for files inside .git or releases below the current project root.
; This prevents old releases or repository internals from affecting version detection.
isExcludedSourcePath(source_dir, file_path)
{
    source_prefix_length := StrLen(RTrim(source_dir, "\/")) + 2
    relative_path := SubStr(file_path, source_prefix_length)


    if RegExMatch(relative_path, "i)^(?:\.git|releases)(?:\\|$)")
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
; .git and releases are excluded so the destination cannot recursively copy itself.
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




; Tests arbitrary script names, version parsing, .ms/.mcr deployment, and exclusions.
; Run with: MaxScript-Deploy.ahk --test
testMaxScriptDeploy()
{
    test_id := A_TickCount
    source_dir := A_Temp . "\MaxScriptDeployTest_" . test_id
    expected_version := "9.876"


    FileCreateDir, %source_dir%
    FileCreateDir, %source_dir%\Scripts\Nested
    FileCreateDir, %source_dir%\Docs
    FileCreateDir, %source_dir%\.git
    FileCreateDir, %source_dir%\releases\8.765


    FileAppend, Project version: %expected_version%.`r`n, %source_dir%\Completely-Different-Name.ms
    FileAppend, macroScript ArbitraryMacro`r`n(`r`n)`r`n, %source_dir%\Scripts\Nested\Another-Name.mcr
    FileAppend, should not deploy`r`n, %source_dir%\Docs\readme.txt
    FileAppend, should not deploy`r`n, %source_dir%\.gitignore
    FileAppend, Project version 1.111.`r`n, %source_dir%\.git\Ignored.ms
    FileAppend, Project version 8.765.`r`n, %source_dir%\releases\8.765\Old.ms


    parsed_version := getProjectVersion(source_dir)
    destination_dir := getDeployDestination(source_dir, parsed_version)
    copied := copyMaxScriptFiles(source_dir, destination_dir)


    passed := true
    passed := passed && (parsed_version = expected_version)
    passed := passed && (destination_dir = source_dir . "\releases\" . expected_version)
    passed := passed && copied
    passed := passed && FileExist(destination_dir . "\Completely-Different-Name.ms")
    passed := passed && FileExist(destination_dir . "\Scripts\Nested\Another-Name.mcr")
    passed := passed && !FileExist(destination_dir . "\Docs\readme.txt")
    passed := passed && !FileExist(destination_dir . "\.gitignore")
    passed := passed && !FileExist(destination_dir . "\.git")
    passed := passed && !FileExist(destination_dir . "\releases")


    FileRemoveDir, %source_dir%, 1


    if (passed)
        MsgBox, 64, MaxScript Deploy Test, PASS - arbitrary script names work and only .ms/.mcr files are deployed.
    else
        MsgBox, 16, MaxScript Deploy Test, FAIL - one or more deployment checks failed.


    return passed
}
