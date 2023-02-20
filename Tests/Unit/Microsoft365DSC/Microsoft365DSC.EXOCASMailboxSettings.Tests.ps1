[CmdletBinding()]
param(
)
$M365DSCTestFolder = Join-Path -Path $PSScriptRoot `
    -ChildPath '..\..\Unit' `
    -Resolve
$CmdletModule = (Join-Path -Path $M365DSCTestFolder `
        -ChildPath '\Stubs\Microsoft365.psm1' `
        -Resolve)
$GenericStubPath = (Join-Path -Path $M365DSCTestFolder `
        -ChildPath '\Stubs\Generic.psm1' `
        -Resolve)
Import-Module -Name (Join-Path -Path $M365DSCTestFolder `
        -ChildPath '\UnitTestHelper.psm1' `
        -Resolve)

$Global:DscHelper = New-M365DscUnitTestHelper -StubModule $CmdletModule `
    -DscResource 'EXOCASMailboxSettings' -GenericStubModule $GenericStubPath
Describe -Name $Global:DscHelper.DescribeHeader -Fixture {
    InModuleScope -ModuleName $Global:DscHelper.ModuleName -ScriptBlock {
        Invoke-Command -ScriptBlock $Global:DscHelper.InitializeScript -NoNewScope

        BeforeAll {
            $secpasswd = ConvertTo-SecureString 'test@password1' -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ('tenantadmin', $secpasswd)

            Mock -CommandName Update-M365DSCExportAuthenticationResults -MockWith {
                return @{}
            }

            Mock -CommandName Get-M365DSCExportContentForResource -MockWith {
            }

            Mock -CommandName Confirm-M365DSCDependencies -MockWith {
            }

            Mock -CommandName New-M365DSCConnection -MockWith {
                return 'Credentials'
            }

            # Mock Write-Host to hide output during the tests
            Mock -CommandName Write-Host -MockWith {
            }
        }

        Context -Name 'CAS Mailbox settings - update not required.' -Fixture {
            BeforeAll {
                $testParams = @{
                    Ensure                 = 'Present'
                    Identity               = 'MeganB'
                    Credential             = $Credential
                    ActiveSyncDebugLogging = $False
                    PopEnabled             = $False
                    EwsEnabled             = $True
                }

                Mock -CommandName Get-CASMailbox -MockWith {
                    return @{
                        Ensure                 = 'Present'
                        Identity               = 'MeganB'
                        Credential             = $Credential
                        ActiveSyncDebugLogging = $False
                        PopEnabled             = $False
                        EwsEnabled             = $True
                    }
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'CAS Mailbox settings - update needed.' -Fixture {
            BeforeAll {
                $testParams = @{
                    Ensure                 = 'Present'
                    Identity               = 'MeganB'
                    Credential             = $Credential
                    ActiveSyncDebugLogging = $False
                    PopEnabled             = $False
                    EwsEnabled             = $True
                }

                Mock -CommandName Get-CASMailbox -MockWith {
                    return @{
                        Ensure                 = 'Present'
                        Identity               = 'ExampleCASRule'
                        Credential             = $Credential
                        ActiveSyncDebugLogging = $True
                        PopEnabled             = $True
                        EwsEnabled             = $False
                    }
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should call the Set method' {
                Set-TargetResource @testParams
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $testParams = @{
                    Credential = $Credential
                }

                Mock -CommandName Get-CASMailbox -MockWith {
                    return @{
                        ActiveSyncDebugLogging = $False
                        PopEnabled             = $False
                        EwsEnabled             = $True
                    }
                }
            }

            It 'Should Reverse Engineer resource from the Export method' {
                Export-TargetResource @testParams
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
