format "\n=======================================================================================================================================\n\nIMPORT FILES FROM: %\n" (getSourceFileName())

file_in_files = #(
)

for file_path in file_in_files do
	if doesFileExist file_path then
	(
		filein file_path
    )
else
		format "\n\n----- WARNING: Missing file in: %\n\nERROR OF IMPORT FILE: %\n" (getSourceFileName()) file_path