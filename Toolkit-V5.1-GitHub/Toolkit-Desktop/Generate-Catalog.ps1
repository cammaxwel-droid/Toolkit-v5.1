#requires -Version 5.1
# Parses source as data. Does not import or execute toolkit commands.
param([string]$ToolkitRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Toolkit-V5.1'))
$ErrorActionPreference = 'Stop'

function Read-CatalogSource {
    param([string]$Path,[string]$Command,[string]$Prefix)
    $tokens=$null; $errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw "Cannot read catalog: syntax errors in $Path" }
    $categoryAssignment=$ast.Find({param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$script:Categories'},$true)
    $categories=@($categoryAssignment.Right.FindAll({param($n) $n -is [System.Management.Automation.Language.HashtableAst]},$true) | ForEach-Object {
        $fields=@{}
        foreach($pair in $_.KeyValuePairs) { $fields[$pair.Item1.Value]=$pair.Item2.PipelineElements[0].Expression.Value }
        [pscustomobject]@{Key=($Prefix+'-'+$fields.Id);Name=$fields.Name;Hint=$fields.Hint;Section=$Prefix}
    })
    $tools=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq $Command},$true) | ForEach-Object {
        $fields=@{}; $elements=$_.CommandElements
        for($i=1;$i -lt $elements.Count-1;$i++) {
            if($elements[$i] -is [System.Management.Automation.Language.CommandParameterAst]) {
                $key=$elements[$i].ParameterName; $value=$elements[$i+1]
                if($key -eq 'Action') { $fields[$key]=$value.Extent.Text.Trim().TrimStart('{').TrimEnd('}').Trim(); break }
                if($value -is [System.Management.Automation.Language.VariableExpressionAst]) { $fields[$key]=($value.VariablePath.UserPath -eq 'true') }
                else { $fields[$key]=$value.Value }
            }
        }
        $categoryKey=$Prefix+'-'+$fields.Category
        [pscustomobject]@{
            Id=$fields.Id;CategoryKey=$categoryKey;CategoryName=($categories|Where-Object Key -eq $categoryKey|Select-Object -ExpandProperty Name)
            Title=$fields.Title;Description=$fields.Description;Risk=$fields.Risk;Admin=$fields.Admin;Preview=$fields.Action;Section=$Prefix
        }
    })
    return [pscustomobject]@{Categories=$categories;Tools=$tools}
}

$main=Read-CatalogSource (Join-Path $ToolkitRoot 'src\Toolkit.ps1') 'Add-ToolkitTool' 'main'
$repair=Read-CatalogSource (Join-Path $ToolkitRoot 'repair-kit\src\RepairKit.ps1') 'Add-RepairTool' 'repair'
$all=@($main.Tools)+@($repair.Tools)
if($main.Tools.Count -ne 180 -or $repair.Tools.Count -ne 51 -or @($all.Id|Sort-Object -Unique).Count -ne 231) { throw 'Expected 180 main commands and 51 Repair Kit commands.' }
if(@($main.Categories).Count -ne 15 -or @($repair.Categories).Count -ne 6) { throw 'Category counts do not match the toolkit.' }
$hashes=[ordered]@{}
foreach($source in Get-ChildItem -LiteralPath $ToolkitRoot -File -Recurse -Filter '*.ps1' | Sort-Object FullName) {
    $file=$source.FullName.Substring(([IO.Path]::GetFullPath($ToolkitRoot).TrimEnd('\')).Length+1).Replace('\','/')
    $hashes[$file]=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
}
$catalog=[ordered]@{Schema=1;Categories=(@($main.Categories)+@($repair.Categories));Tools=$all;SourceHashes=$hashes}
$dir=Join-Path $PSScriptRoot 'Data'
[void][IO.Directory]::CreateDirectory($dir)
[IO.File]::WriteAllText((Join-Path $dir 'Catalog.json'),($catalog|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
Write-Output 'Catalog generated from source: 180 main commands, 51 Repair Kit commands, 21 categories.'
