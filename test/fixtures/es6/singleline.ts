import DefaultTs from "just-default.ts";
import * as WildcardTs from 'just-wildcard.ts';
import { america, britain as uk, congo } from 'countries.ts';
import $Default, {bar} from "default-and-named.ts";
import default_ts, * as wildcardts$ from 'default-and-wildcard.ts';
import apple from 'os.ts';

function f() {
  console.log(DefaultTs, WildcardTs, america, uk, congo, $DefaultTs, bar, default_ts, wildcardts$);
}
