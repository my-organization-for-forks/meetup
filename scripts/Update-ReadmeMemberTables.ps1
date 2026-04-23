param(
  [string]$ReadmePath = "README.md",
  [string]$MembersCsvPath = "data/readme-members.csv",
  [int]$Columns = 8
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Escape-Html {
  param([string]$Value)

  return [System.Net.WebUtility]::HtmlEncode($Value)
}

function Get-AvatarUrl {
  param([string]$Username)

  return "https://github.com/$Username.png?size=100"
}

function Render-MemberTable {
  param(
    [object[]]$Entries,
    [int]$ColumnCount
  )

  if (-not $Entries -or $Entries.Count -eq 0) {
    return "<!-- No entries found -->"
  }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("<table>")

  for ($rowStart = 0; $rowStart -lt $Entries.Count; $rowStart += $ColumnCount) {
    $lines.Add("  <tr>")

    for ($columnIndex = 0; $columnIndex -lt $ColumnCount; $columnIndex++) {
      $entryIndex = $rowStart + $columnIndex

      if ($entryIndex -ge $Entries.Count) {
        $lines.Add("    <td></td>")
        continue
      }

      $entry = $Entries[$entryIndex]
      $username = Escape-Html $entry.username
      $label = Escape-Html ($(if ($entry.label) { $entry.label } else { $entry.username }))
      $profileUrl = "https://github.com/$username"
      $avatarUrl = Get-AvatarUrl $username

      $lines.Add("    <td align=""center"">")
      $lines.Add("      <a href=""$profileUrl"" title=""$label"">")
      $lines.Add("        <img src=""$avatarUrl"" width=""50"" height=""50"" alt=""$label"" />")
      $lines.Add("      </a>")
      $lines.Add("    </td>")
    }

    $lines.Add("  </tr>")
  }

  $lines.Add("</table>")
  return ($lines -join "`n")
}

function Replace-MarkedBlock {
  param(
    [string]$Content,
    [string]$StartMarker,
    [string]$EndMarker,
    [string]$Replacement
  )

  if ($Content.IndexOf($StartMarker) -lt 0) {
    throw "Missing start marker: $StartMarker"
  }

  if ($Content.IndexOf($EndMarker) -lt 0) {
    throw "Missing end marker: $EndMarker"
  }

  $pattern = "(?s)" + [regex]::Escape($StartMarker) + ".*?" + [regex]::Escape($EndMarker)
  $updated = [regex]::Replace(
    $Content,
    $pattern,
    "$StartMarker`n$Replacement`n$EndMarker",
    1
  )

  return $updated
}

$members = Import-Csv -Path $MembersCsvPath -Encoding utf8
$readme = Get-Content -Path $ReadmePath -Raw -Encoding utf8

$sectionConfig = @(
  @{
    name = "staff"
    start = "<!-- START:staff-table -->"
    end = "<!-- END:staff-table -->"
  },
  @{
    name = "participants"
    start = "<!-- START:participants-table -->"
    end = "<!-- END:participants-table -->"
  }
)

foreach ($section in $sectionConfig) {
  $entries = @($members | Where-Object { $_.section -eq $section.name })
  $replacement = Render-MemberTable -Entries $entries -ColumnCount $Columns
  $readme = Replace-MarkedBlock -Content $readme -StartMarker $section.start -EndMarker $section.end -Replacement $replacement
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Resolve-Path $ReadmePath), $readme, $utf8NoBom)
