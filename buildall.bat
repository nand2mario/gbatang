
@REM 'x REG unPlaced' problem:
@REM 1.9.11 placement algo 3 works

set GWSH=\Gowin\Gowin_V1.9.10.03_x64\IDE\bin\gw_sh

echo
echo "============ Building console60k ==============="
echo
%GWSH% build.tcl console60k

echo
echo "============ Building mega60k ==============="
echo
%GWSH% build.tcl mega60k 

echo
echo "============ Building mega138k ==============="
echo
%GWSH% build.tcl mega138k

echo
echo "============ Building mega138k pro ==============="
echo
%GWSH% build.tcl mega138kpro

dir impl\pnr\*.fs

echo "All done."

