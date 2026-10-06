\# Toolsets Design

Use this file as the source of truth for feature design at the Toolsets layer.

Record the intended design of larger Toolsets here. A Toolset composes related Tools, owns the top-level dialog or container, and coordinates only state or behavior that genuinely belongs across multiple Tools.

\#\# What belongs here

For each Toolset feature, record:

\- purpose and overall workflow;  
\- Tools included in the Toolset;  
\- Toolset backend responsibilities;  
\- Toolset frontend / top-level UI responsibilities;  
\- cross-Tool state or coordination;  
\- Tool loading and ordering;  
\- dialog/container behavior;  
\- important edge cases or constraints.

\#\# Feature design template

\#\#\# \<Toolset name\>

\*\*Purpose:\*\*    
\<What larger workflow or system this Toolset provides.\>

\*\*Tools included:\*\*    
\<Related Tools contained or coordinated by this Toolset.\>

\*\*Backend design:\*\*    
\<Responsibilities of \`\<ToolsetName\>-FN.ms\`.\>

\*\*UI design:\*\*    
\<Responsibilities of \`\<ToolsetName\>-UI.ms\` and the top-level container.\>

\*\*Main entry behavior:\*\*    
\<What \`\<ToolsetName\>.ms\` loads and executes.\>

\*\*Shared state / coordination:\*\*    
\<State or behavior shared across Tools.\>

\*\*Tool loading / ordering:\*\*    
\<Required loading and presentation order.\>

\*\*Edge cases / constraints:\*\*    
\<Important limits or integration rules.\>

\#\# Feature designs

Add approved Toolset designs below this heading.  
