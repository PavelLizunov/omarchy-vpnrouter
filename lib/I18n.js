.pragma library

/**
 * I18n.js - Systematic localization engine for VPNRouter
 * Supports English and Russian with fallback, interpolation, and locale detection.
 */

var catalogs = {
  en: null,
  ru: null
};

var currentLocale = "auto";
var systemLocale = "en";
var revision = 0;
var listeners = [];

function getRevision() {
  return revision;
}

function addListener(cb) {
  if (typeof cb === "function" && listeners.indexOf(cb) === -1) {
    listeners.push(cb);
  }
}

function removeListener(cb) {
  var idx = listeners.indexOf(cb);
  if (idx !== -1) {
    listeners.splice(idx, 1);
  }
}

function notifyChange() {
  revision++;
  for (var i = 0; i < listeners.length; i++) {
    try {
      listeners[i](revision);
    } catch (e) {}
  }
}

function setCatalogs(enDict, ruDict) {
  if (enDict) catalogs.en = enDict;
  if (ruDict) catalogs.ru = ruDict;
  notifyChange();
}

function detectSystemLocale(envLang) {
  var l = String(envLang || "en").toLowerCase();
  if (l.indexOf("ru") === 0 || l.indexOf("be") === 0 || l.indexOf("kk") === 0) {
    return "ru";
  }
  return "en";
}

function setLocale(loc, envLang) {
  if (envLang) {
    systemLocale = detectSystemLocale(envLang);
  }
  if (loc === "ru" || loc === "en") {
    currentLocale = loc;
  } else {
    currentLocale = "auto";
  }
  notifyChange();
}

function getEffectiveLocale(revisionArg) {
  if (currentLocale === "auto") {
    return systemLocale || "en";
  }
  return currentLocale;
}

// CLDR cardinal rules for nonnegative integer app counts in our two catalogs.
// https://www.unicode.org/cldr/charts/49/supplemental/language_plural_rules.html
// Qt's QML engine has no Intl.PluralRules; tests compare these rules to ICU.
function cardinalCategory(count, locale) {
  if (typeof count !== "number" || !isFinite(count) || count < 0 || Math.floor(count) !== count) return null;
  if (locale !== "ru") return count === 1 ? "one" : "other";
  var tens = count % 100, units = count % 10;
  if (units === 1 && tens !== 11) return "one";
  if (units >= 2 && units <= 4 && (tens < 12 || tens > 14)) return "few";
  return "many";
}

function formatString(template, args) {
  if (!template || typeof template !== "string") return "";
  if (!args) return template;
  if (Array.isArray(args)) {
    return template.replace(/\{(\d+)\}/g, function(match, index) {
      var idx = parseInt(index, 10);
      return (idx >= 0 && idx < args.length && args[idx] !== undefined) ? String(args[idx]) : match;
    });
  }
  if (typeof args === "object") {
    return template.replace(/\{([A-Za-z0-9_]+)\}/g, function(match, key) {
      return (args[key] !== undefined) ? String(args[key]) : match;
    });
  }
  return template.replace(/\{0\}/g, String(args));
}

function t(key, args, overrideLocale, revisionArg) {
  if (!key || typeof key !== "string") return "";
  var lang = overrideLocale || getEffectiveLocale();
  var dict = catalogs[lang];
  var text = (dict && typeof dict[key] === "string") ? dict[key] : null;

  // Fallback to English if missing in target locale
  if (text === null && lang !== "en") {
    var enDict = catalogs.en;
    if (enDict && typeof enDict[key] === "string") {
      text = enDict[key];
    }
  }

  // Fallback to raw key
  if (text === null) {
    text = key;
  }

  return formatString(text, args);
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    setCatalogs: setCatalogs,
    detectSystemLocale: detectSystemLocale,
    setLocale: setLocale,
    getEffectiveLocale: getEffectiveLocale,
    getRevision: getRevision,
    addListener: addListener,
    removeListener: removeListener,
    notifyChange: notifyChange,
    formatString: formatString,
    cardinalCategory: cardinalCategory,
    t: t
  };
}
