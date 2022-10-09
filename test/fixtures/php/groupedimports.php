<?php
namespace NS\With\GroupedImports;

use Comma\Group\Number1, Comma\Group\Number2 as No2, Comma\Group\More, Unrelated\Whatever;
use Brace\Group\{BG1 as BraceGroupOne, BG2, BG3};
use Multi\Line\Comma1,
	Multi\Line\Comma2,
	Multi\Line\Comma3;
use Multi\Line\{
	Brace1, function Brace2, const Brace3,
	function BraceFunc as RenamedBraceFunc,
	const BraceConst as RenamedBraceConst,
};
