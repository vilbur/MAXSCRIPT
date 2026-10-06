/*
Creates the standard dark WinForms .NET button style.
Use this as the canonical default button template.
*/
function setupDarkButton btn =
(
	color_class = dotNetClass "System.Drawing.Color"
	font_style_class = dotNetClass "System.Drawing.FontStyle"
	flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"

	btn.UseVisualStyleBackColor = false
	btn.FlatStyle = flat_style_class.Flat

	btn.BackColor = color_class.FromArgb 68 68 68
	btn.ForeColor = color_class.FromArgb 190 190 190

	btn.FlatAppearance.BorderColor = color_class.FromArgb 120 120 120
	btn.FlatAppearance.BorderSize = 1

	btn.FlatAppearance.MouseOverBackColor = color_class.FromArgb 78 78 78
	btn.FlatAppearance.MouseDownBackColor = color_class.FromArgb 55 55 55

	btn.Font = dotNetObject \
		"System.Drawing.Font" \
		"Segoe UI" \
		9.0 \
		font_style_class.Bold

	btn -- return
)
