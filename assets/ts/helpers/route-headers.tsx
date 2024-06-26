/* eslint-disable @typescript-eslint/no-explicit-any */
import React from "react";
import { Route } from "../__v3api";
import { isASilverLineRoute } from "../models/route";
import { breakTextAtSlash } from "./text";
import { busClass } from "./css";
import CRsvg from "../../../priv/static/icon-svg/icon-commuter-rail-default.svg";
import Bussvg from "../../../priv/static/icon-svg/icon-bus-default.svg";
import SubwaySvg from "../../../priv/static/icon-svg/icon-subway-default.svg";
import FerrySvg from "../../../priv/static/icon-svg/icon-ferry-default.svg";

export function routeToModeIcon(route: Route): any {
  switch (route.type) {
    case 0:
    case 1:
      return SubwaySvg;
    case 2:
      return CRsvg;

    case 3:
      return Bussvg;

    case 4:
      return FerrySvg;

    default:
      return null;
  }
}

export function routeName(route: Route): JSX.Element {
  return (
    <span className={busClass(route)}>
      {isASilverLineRoute(route.id)
        ? `Silver Line ${route.name}`
        : breakTextAtSlash(route.name)}
    </span>
  );
}
