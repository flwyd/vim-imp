const a = import("dynamic-imports-are-ignored");
import Default from 'just-default.js';
import * as Wildcard from 'just-wildcard.js';
import {apple, banana, cherry, durian} from "fruit.js";
import default_and, { a as foo } from 'default-and-named.js';
import $Default, * as wildcard from "default-and-wildcard.js";
import * as congo from 'the-jungle.js';

function f() {
  console.log(Default, Wildcard, apple, banana, cherry, durian, default_and, foo, $Default, wildcard_too);
}
