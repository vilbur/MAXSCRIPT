#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1

/*
Gets the agent language name from the folder containing this script.
Example: C:\AI\Agents\Maxscript -> Maxscript
*/
getAgentLanguage()
{
    SplitPath, A_ScriptDir, language_name
    return language_name
    ; -- return
}

/*
Creates the project Agents folder when it does not already exist.
*/
ensureAgentsFolder(project_path)
{
    agents_path := project_path . "\Agents"

    if !FileExist(agents_path)
        FileCreateDir, %agents_path%

    if !InStr(FileExist(agents_path), "D")
    {
        MsgBox, 16, Agent Link, Failed to create Agents folder.`n`n%agents_path%
        return false
    }

    return true
    ; -- return
}

/*
Creates a language-specific junction from Project\Agents\<Language> to A_ScriptDir.
*/
createAgentLanguageLink(project_path, language_name)
{
    source_path := A_ScriptDir
    agents_path := project_path . "\Agents"
    link_path := agents_path . "\" . language_name

    if !FileExist(project_path)
    {
        MsgBox, 16, Agent Link, Project folder does not exist.`n`n%project_path%
        return false
    }

    if !ensureAgentsFolder(project_path)
        return false

    if FileExist(link_path)
    {
        MsgBox, 48, Agent Link, This path already exists:`n`n%link_path%
        return false
    }

    command := ComSpec . " /C mklink /J " . Chr(34) . link_path . Chr(34) . " " . Chr(34) . source_path . Chr(34)
    RunWait, %command%,, Hide UseErrorLevel

    if (ErrorLevel != 0 || !FileExist(link_path))
    {
        MsgBox, 16, Agent Link, Failed to create junction.`n`nSource:`n%source_path%`n`nTarget:`n%link_path%
        return false
    }

    return true
    ; -- return
}

/*
Creates a minimal project AGENTS.md pointing Codex to the linked language instructions.
Existing AGENTS.md files are never overwritten.
*/
createAgentsFile(project_path, language_name)
{
    agents_file := project_path . "\AGENTS.md"
    relative_agent_path := "Agents/" . language_name

    if FileExist(agents_file)
        return true

    content := "# Project agent instructions`r`n`r`n"
    content .= "For " . language_name . " tasks, read and follow the shared instructions in `" . relative_agent_path . "` before working on the task.`r`n"

    FileAppend, %content%, %agents_file%, UTF-8

    if ErrorLevel
    {
        MsgBox, 48, Agent Link, Junction was created, but AGENTS.md could not be created.`n`n%agents_file%
        return false
    }

    return true
    ; -- return
}

/*
Tests language-name detection without modifying any project.
Expected result is the name of the folder containing this script.
*/
testAgentLanguage()
{
    language_name := getAgentLanguage()
    MsgBox, 64, Agent Link Test, Detected language:`n`n%language_name%
    return true
    ; -- return
}

language_name := getAgentLanguage()

if (language_name = "")
{
    MsgBox, 16, Agent Link, Could not determine the agent language from A_ScriptDir.
    ExitApp
}

FileSelectFolder, project_path, *%A_WorkingDir%, 3, BROWSE FOR PROJECT DIRECTORY OF %language_name% PROJECT
if ErrorLevel
    ExitApp

if (project_path = "")
    ExitApp

if createAgentLanguageLink(project_path, language_name)
{
    agents_created := createAgentsFile(project_path, language_name)

    if agents_created
    {
        MsgBox, 64, Agent Link, Done.`n`nLanguage: %language_name%`nSource: %A_ScriptDir%`nProject link: %project_path%\Agents\%language_name%
    }
}

ExitApp
