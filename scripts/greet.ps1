# PowerShell 인사말 스크립트
# 사용자의 이름을 받아 인사말을 출력한다

param(
  [string]$Name = "손님"
)

# 이름이 명시되지 않은 경우 기본값 사용
if ([string]::IsNullOrWhiteSpace($Name)) {
  $Name = "손님"
}

# 인사말 출력
Write-Host "안녕하세요, $($Name)님!"
