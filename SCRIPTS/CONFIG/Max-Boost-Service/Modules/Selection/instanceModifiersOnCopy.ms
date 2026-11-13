/**
  * @param 2Dmatrix cloned_nodes of nodes E.G.: #( #(source objects) #(copies 1) #(copies 2) #(copies 3) )
  * 
  * @param #COPY|#INSTANCE|#REFERENCE clone_type
 */
function instanceModifiersOnCopy cloned_nodes clone_type =
(
	--print "instanceModifiersOnCopy()"
	--format "clone_type: %\n" clone_type
	
	/** Instance modifier
	 */
	function instanceModifier source_node dest_node _modifier index =
	(
		--if dest_node.modifiers[index] != undefined then 
			deleteModifier dest_node index
		
		addModifierWithLocalData dest_node _modifier source_node _modifier before:(index - 1) -- instance the modifier
	)
	
	
	objs_with_modifiers = for obj in cloned_nodes[1] where obj.modifiers.count > 0 collect obj
	
	
	if objs_with_modifiers.count > 0 and clone_type == #COPY and queryBox ("Instance modifiers to new nodes ?") then
	--if queryBox ("Instance modifiers to new nodes ?") then
	(
		current_panel = getCommandPanelTaskMode()
		
		max create mode
		
		/* FOR EACH SOURCE OBJECT */ 
		for y = 1 to cloned_nodes[1].count do
		(
			source_node = cloned_nodes[1][y]
			--format "\n-------------\n"
			--format "source_node: %\n" (source_node.name)
			--format "dest_node: %\n" (source_node.name)
			
			/* FOR EACH OBJECT COPY */ 
			for x = 2 to cloned_nodes.count do
			(
				dest_node = cloned_nodes[x][y]
				--format "\n"
				--format "dest_node: %\n" dest_node
				
				/* FOR EACH MODIFIER */ 
				for m = source_node.modifiers.count to 1 by -1 do
				(
					--format "MODIFIER: %\n" (source_node.modifiers[m])
					instanceModifier source_node dest_node source_node.modifiers[m] m
					
				)
				
			)
				
		)
	
		setCommandPanelTaskMode mode:current_panel
	)
)
