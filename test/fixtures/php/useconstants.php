<?php
namespace Using\Constants;

// use const SHOULD_NOT_BE_FOUND;
use const PHP_MAJOR_VERSION, PHP_MINOR_VERSION, PHP_RELEASE_VERSION;
use const E_ALL;
use const E_ERROR ;
use const __COMPILER_HALT_OFFSET__;
use const Ns\With\Constants\Const1;
use const Ns\With\Constants\Renamed as OtherName;

echo
"use const CONSTTANT_NOT_DEFIINED;\n";

echo PHP_MINOR_VERSION * PHP_RELEASE_VERSION / PHP_MAJOR_VERSION;

echo E_ALL & E_ERROR;

if (__COMPILER_HALT_OFFSET__ > 0) {
	throw new \Exception('use const CONST_IN_STRING;');
}
