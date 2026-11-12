/// runner restricted to the TTestCoreBase regression tests, for issue #648
program test648;

{$I mormot.defines.inc}

uses
  {$I mormot.uses.inc}
  mormot.core.base,
  mormot.core.os,
  mormot.core.test,
  test.core.base;

type
  TTest648 = class(TSynTestsLogged)
  published
    procedure Core;
  end;

procedure TTest648.Core;
begin
  AddCase([TTestCoreBase]);
end;

begin
  TTest648.RunAsConsole('test648');
end.
