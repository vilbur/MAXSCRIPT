\# Operations Design

Use this file as the source of truth for feature design at the Operations layer.

Record the intended behavior of reusable Operations here before or while implementing them. Operations compose Functions into complete logical procedures, so this file should describe workflow and result contracts rather than UI.

\#\# What belongs here

For each Operation feature, record:

\- purpose;  
\- required Function dependencies;  
\- input contract;  
\- execution order;  
\- validation and branching rules;  
\- output or result contract;  
\- failure behavior;  
\- important edge cases or constraints.

\#\# Feature design template

\#\#\# \<Operation feature name\>

\*\*Purpose:\*\*    
\<What complete logical procedure this Operation provides.\>

\*\*Inputs:\*\*    
\<Required parameters and accepted values.\>

\*\*Function dependencies:\*\*    
\<Functions called by this Operation.\>

\*\*Workflow:\*\*    
\<Required sequence, branching, and validation.\>

\*\*Output:\*\*    
\<Return value or result contract.\>

\*\*Failure behavior:\*\*    
\<How failures are detected and reported.\>

\*\*Edge cases / constraints:\*\*    
\<Important limits or unsupported cases.\>

\#\# Feature designs

Add approved Operation designs below this heading.  
