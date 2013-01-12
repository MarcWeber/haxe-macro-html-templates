package mw;
import mw.ArrayExtensions;
import mw.ReflectionExtensions;

import haxe.macro.Expr;
import haxe.macro.Context;


// for debugging return string
typedef E = 
#if macro
  Expr
#else
  String
#end

// this get's parsed {{{
enum Attribute {
  attr_expr(e:E); // must recturn hash or {} object
  attr_name_value(name:String, value:String);
  attr_name_expr_as_value(name:String, expr:E);
}

enum ParsedTemplateItem {
  text(s:String); // html
  expr(e:E, quoted: Bool); // e should return a string
  filter(name:String, e:TemplateContent);
  tag(name:String, attributes:Array<Attribute>, contents:TemplateContent, add_space:Bool);

  control_if(cond:E, then_: TemplateContent, else_: TemplateContent /* can be empty list*/);

  // for (..) true; will be parsed true will then be substituted by the content
  control_for(for_:E, content: TemplateContent);
  
  // case ..
}
typedef TemplateContent = Array<ParsedTemplateItem>;
// }}}

// parsing the template files is that simple, no backtracking required.
// we just throw an Exception on error
typedef ParserState = {
  s:String,
  i:Int,
  pos: {min: Int, max:Int, file:String},
  available_filters: Array<String>
};

#if macro
class ExprBuilder {
  public var items:Array<Expr>;
  public function new() {
    items = [];
  }

  public function s(s:String) {
    var e:Expr;
    if (items.length > 0){
      var last_s = ReflectionExtensions.value_at_path(ArrayExtensions.last(items).expr, ["EConst",0,"CString",0]);
      if (last_s != null){
        items[items.length-1] = macro $v{last_s + s};
        return;
      }
    }
    items.push(macro $v{s});
  }

  public function expr(e:Expr) {
    items.push(e);
  }
}
#end

// TODO: think about where to use return LazyMacro.lazy({
class TemplateParser {

  static public var autoclose = ["meta","img","link","br","hr","input","area","param","col","base"];

#if macro
  static public function makePos(ps: ParserState) {
    var p = ps.pos.min +ps.i;
    return Context.makePosition({min: p, max: p, file:ps.pos.file});
  }
#end

  static public function parse_failure(ps:ParserState, msg:String) {
    var msg = msg;
#if macro
    // msg += " at bytepos "+ ps.i +": "+ps.s.substr(ps.i);
    Context.error(msg, makePos(ps));
#else
    throw msg+" at bytepos "+ ps.i +": "+ps.s.substr(ps.i);
#end
  }


  static inline function code(ps: ParserState) {
    return StringTools.fastCodeAt(ps.s, ps.i);
  }

  @:macro static function c(char_str: ExprOf<String>):ExprOf<Int> {
    var i:Int = StringTools.fastCodeAt(ReflectionExtensions.value_at_path(char_str.expr, ["EConst",0,"CString",0]), 0);
    return macro $v{i};
  }

  static function exprToCode(char_str:Expr):Int{
    return StringTools.fastCodeAt(ReflectionExtensions.value_at_path(char_str.expr, ["EConst",0,"CString",0]), 0);
  }

  @:macro static function is_string(string:ExprOf<String>):ExprOf<Bool> {
    var s = ReflectionExtensions.value_at_path(string.expr, ["EConst",0,"CString",0]);
    return macro {
      if (ps.s.substr(ps.i, $string.length) == $string){
        ps.i += $string.length;
        true;
      } else {
        false;
      }
    };
  }

  @:macro static function is_char(char:ExprOf<String>):ExprOf<Bool> {
    return macro (!eof(ps) && StringTools.fastCodeAt(ps.s, ps.i) == $v{exprToCode(char)});
  }

  @:macro static function expect_char(char:ExprOf<String>):ExprOf<Bool> {
    return macro if (StringTools.fastCodeAt(ps.s, ps.i) != $v{exprToCode(char)}) parse_failure(ps,  "expected :`"+$char+"`");
  }

  static public function spaces(count:Int, ps:ParserState) {
    var i_ = ps.i;
    while (count > 0 && is_char(" ")) { count --; ps.i++; }
    if (count == 0)
      return true;
    else {
      ps.i = i_;
      return false;
    }
  }

  static inline public function eof(ps:ParserState) {
    return ps.i >= ps.s.length;
  }

  static inline public function ignore_spaces(ps:ParserState) {
    while (is_char(" ")) ps.i++;
  }

  static public function parse_name_like(ps:ParserState) {
    var name = "";
    while (!eof(ps)) {
      var c = code(ps);
      if ((c >= 97 && c <= 122) /* a-z */ || (c >= 48 && c <= 57) /* 0-9 */ || c == 95){
        name += ps.s.charAt(ps.i);
        ps.i++;
      } else break;
    }
    return name;
  }

  static public function parse_attr_value(ps) {
    var c = code(ps);
    if (c == 34 /*"*/ || c == 39 /* ' */)
      ps.i++;
    else
      parse_failure(ps, "attr value expected quoted by ' or \"");
    var start = ps.i;
    while (!eof(ps) && !is_char("\"") && !is_char("'")) ps.i++;
    ps.i++;
    return ps.s.substr(start, ps.i - start -1);
  }

  static public function parse_tag(ii:Int, ps:ParserState):ParsedTemplateItem {
    var name = 'div';
    var attributes = [];
    var add_space = true;

    var add_attr = function(name, value){
      // add to existing class entry:
      var attr_added = false;
      for(i in 0...attributes.length){
        switch(attributes[i]) {
          case attr_name_value(n_, c_):
             if (n_ == name){
               if (name == "class"){
                 attributes[i] = attr_name_value(name, c_+" "+value);
                 attr_added = true;
               } else {
                  parse_failure(ps, "duplicate attr definition "+name);
               }
             }
             break;
          case _:
        }
      }
      if (!attr_added) attributes.push(attr_name_value(name, value));
    };

    var add_id = function(name){
      // add to existing class entry:
      var attr_added = false;
      for(i in 0...attributes.length){
        switch(attributes[i]) {
          case attr_name_value("class", c_):
             attributes[i] = attr_name_value("class", c_+" "+name);
             attr_added = true;
             break;
          case _:
        }
      }
    };

    // name:String, attributes:Array<Attribute>, contents:TemplateContent
    switch (code(ps)) {
      // tag name after %
      case 37 /*%*/: 
        // parse tag name
        ps.i++; name = parse_name_like(ps);
      case _:
    }

    // add .foo or #bar class/id tags
    while (!eof(ps)){
      switch (code(ps)) {
        case 46 /*.*/:
          ps.i++;
          var name = parse_name_like(ps);
          add_attr("class", name);
        case 35 /*#*/:
          ps.i++;
          var name = parse_name_like(ps);
          add_attr("id", name);
        case _:
          break;
      }
    }

    // parse attributes
    if (is_char("(")){
        ps.i++;
        ignore_spaces(ps);
        while (!eof(ps) && !is_char(")")){
          // parse attributes
          ignore_spaces(ps);
          if (is_char("$")){
            // injections
            ps.i++;
            attributes.push(attr_expr(parse_haxe_expr(ps)));
          } else {
            // hard coded name value pair
            var name = parse_name_like(ps);
            expect_char("="); ps.i++;
            if (is_char("$")){
              ps.i++;
              attributes.push(attr_name_expr_as_value(name, parse_haxe_expr(ps)));
            } else {
              add_attr(name, parse_attr_value(ps));
            }
          }

          ignore_spaces(ps);
        }
        expect_char(")"); ps.i++;
    }

    if (is_char('>')){
      ps.i++; add_space = false;
    }

    // parse content if any
    var contents = [];
    if (is_char("=")){
      // one line
      ps.i++;
      contents.push(expr(parse_haxe_expr(ps), true));
      if (!eof(ps)){  expect_char("\n"); ps.i++; }
    } else if (is_char("!")){
      // one line
      ps.i++;
      expect_char("="); ps.i++;
      contents.push(expr(parse_haxe_expr(ps), false));
      if (!eof(ps)){ expect_char("\n"); ps.i++; }
    } else if (is_char("\n")){
      ps.i++;
      if (!eof(ps)){
        // now test for items having one additional indentation level ..
        parse_template_items(ii + 2, ps, contents);
        // if (!eof(ps)) { expect_char("\n"); ps.i++;}
      }
    } else {
      // text after )
      ignore_spaces(ps);
      parse_text_line(ps, contents, true);
      if (!eof(ps)) { expect_char("\n"); ps.i++;}
    }
    if (ArrayExtensions.contains(autoclose,name) && contents != [])
      parse_failure(ps, "tag with children found which is not expected to have childs");
    return tag(name, attributes, contents, add_space);
  }

  static public function walk_haxe_expr(ps:ParserState, repeat:Bool = false) {

    ignore_spaces(ps);
    while (true){
      var start = ps.i;
      var co = code(ps);
      switch (co){
        case 34 /* " */:
          // parse string
          ps.i++;
          while (true){
            var c = code(ps);
            if (c == 34){ ps.i++; break; }
            if (c == 92 /* \ */) ps.i += 2;
            else ps.i++;
          }
        case 39 /* ' */:
          // parse string
          ps.i++;
          while (true){
            var c = code(ps);
            if (c == 39){ ps.i++; break; }
            if (c == 92 /* \ */) ps.i += 2;
            else ps.i++;
          }
        case 40 /* ( */:
          ps.i++; walk_haxe_expr(ps, true);
          ignore_spaces(ps);
          expect_char(")"); ps.i++;
        case 123 /* { */:
          ps.i++; walk_haxe_expr(ps, true);
          ignore_spaces(ps);
          expect_char("}"); ps.i++;
        case 32 /* ' ' */:
          if (repeat) ps.i++;
          else break;
        case _:
          if (co == 125 /* } */ || co == 41 /* ) */) break;
          // anything else such as foo.bar
          while (!eof(ps)){
            var c = code(ps);
            if ((c >= 97 && c <= 122) /* a-z */ || (c >= 65 && c <= 90) /* A-Z */ 
                || c == 95 /*_*/ || c == 46 /*.*/
                || c == 43 /*+*/ || c == 115 /*-*/
                || c == 42 /***/ || c == 47 /*/*/
                || c == 63 /*?*/ || c == 58 /*:*/
                )
              ps.i++;
            else break;
          }
      }

      if (start == ps.i) break;
    }
  }
  static public function parse_haxe_expr(ps:ParserState):E {
    var i = ps.i;
    walk_haxe_expr(ps);
    var s = ps.s.substr(i, ps.i - i);
#if macro
    return Context.parse(s, makePos(ps));
#else
    return s;
#end
  }

  // for, while etc
  static public function parse_code(ii:Int, ps:ParserState):ParsedTemplateItem {
    expect_char(":"); ps.i++;
    if (is_string('if')){
      // if
      ignore_spaces(ps);
      // todo , pass location of template string
      var cond_expr = parse_haxe_expr(ps);
      expect_char("\n"); ps.i++;
      var then_content = [];
      parse_template_items(ii+2, ps, then_content);
      var else_content = [];
      // else branch?
      var i = ps.i;
      if (spaces(ii, ps)){
        if (is_string(":else")){
          expect_char("\n"); ps.i++;
          parse_template_items(ii+2, ps, else_content); 
        } else {
          // we're done, no else branch
          ps.i = i;
        }
      }
      return control_if(cond_expr, then_content, else_content);

    } else if (is_string('for')) {
      // for
      var i = ps.i;
      while (!is_char("\n") && !eof(ps)) ps.i++;
      var for_s = ps.s.substr(i, ps.i-i);
      var for_ = 
#if macro
          Context.parse(for_s, makePos(ps));
#else
          for_s;
#end
      ps.i++; // \n
      var for_content = [];
      parse_template_items(ii+2, ps, for_content); 
      return control_for(for_, for_content);
    } else {
      // try filter ..
      var filter_name = parse_name_like(ps);
      expect_char("\n"); ps.i++;
      var content = [];
      parse_template_items(ii+2, ps, content); 
      if (ArrayExtensions.contains(ps.available_filters, filter_name)){
        return filter(filter_name, content); // dummy, parse_failure throwsn exception
      } else {
        parse_failure(ps, ":for, :if or any of the known filters "+ ps.available_filters.join(",")+" prefixed by : expected");
        return null; // never called
      }
    }
  }

  static public function parse_text_line(ps, r:Array<ParsedTemplateItem>, first_line:Bool) {
    // do not eat \n
    if (is_char(' ') && first_line)
      parse_failure(ps, "unexpected space");
    var l = r.length;
    while (!eof(ps)){
      var c = code(ps);
      if (c == 33 /*!*/ || c == 36 /*$*/){
        ps.i++;
        // interpolation
        expect_char("{"); ps.i++;
        r.push(expr(parse_haxe_expr(ps), c == 36));
        expect_char("}"); ps.i++;
        if (is_char("\n")) break;
      } else {
        // text
        var s = "";
        var next = 10;
        while (!eof(ps)){
          next = code(ps);
          if (next == 10 /* \n */) break;
          else if (next == 36 /*$*/ || next == 33 /*!*/){
            // interpolation starts, so end
            break;
          } else if (next == 92 /* \ */){
            // quote next char, ignore
            ps.i++;
            s += ps.s.charAt(ps.i);
            ps.i++;
          } else {
            // this can be optimized by using substring
            s += ps.s.charAt(ps.i);
            ps.i++;
          }
        }
        if (s != "")
          r.push(text(s));
        if (next == 10) break;
      }
    }
  }

  // text is either:
  // = expr
  // != expr
  // text ${expr} !{expr} or such
  static public function parse_text(ii:Null<Int>, ps:ParserState, r:Array<ParsedTemplateItem> ) {
   // if initial indent is null don't eat trailing whitespace, this happens in parse_tag

    var first_line = true;
    while (!eof(ps)){
      var i = ps.i;
      // optionally parse indent
      if (ii != null && !first_line && !spaces(ii, ps))
        return;

      var code = code(ps);
      // stop if line is not a text line
      if (code == 37 /*%*/ || code == 46 /*.*/ || code == 35 /*#*/){
        if (ii == null) throw "unexpected";
        else {
          // no longer a text line, return
          ps.i = i;
          return;
        }
      }
      // expr lines:
      if (code == 61 /*=*/ || code == 33 /*!*/){
        var quoted = true;
        ps.i++;
        if (code == 33){ expect_char("="); ps.i++; quoted = false; }
        r.push(expr(parse_haxe_expr(ps), quoted));
        if (ii==null) return;
        if (!eof(ps)) { expect_char("\n"); ps.i++; }
      } else {
        // must be a text line ..
        if (!first_line)
        r.push(text(" "));
        var x = r.length;
        parse_text_line(ps, r, first_line);
        // if no item was added, remove the space again
        if (x == r.length)
          r.pop();
        if (ii==null) return;
        if (!eof(ps)) { expect_char("\n"); ps.i++; }
      }
      first_line = false;
    }
  }

  static function parse_template_items(ii:Int, ps: ParserState, r:TemplateContent){
    while (!eof(ps)){
      // drop spaces:
      var i = ps.i;
      if (!spaces(ii, ps)){ ps.i = i; break; }
      if (is_string("-#")){
          while (!eof(ps) && !is_char("\n")) ps.i++;
          ps.i++;
          var dummy = [];
          parse_template_items(ii+2, ps, dummy);
      } else
      switch (code(ps)) {
        // tags
        case 37 /*%*/: r.push(parse_tag(ii, ps));
        case 46 /*.*/: r.push(parse_tag(ii, ps));
        case 35 /*#*/: r.push(parse_tag(ii, ps));

        // code
        case 58 /*:*/: r.push(parse_code(ii, ps));
        case _: parse_text(ii, ps, r);
      }
    }
  }

#if macro
  // the Expr evaluate to a String
  // later more complicated types such as string builders could be supported,
  // too. In the past I did some benchmarks - concatenating strings is that
  // optimized that it may not pay off using builders
  static public function template_content_to_expr(ptis:Array<ParsedTemplateItem>, last_no_space:Bool, e:
      {
        // html: String -> Expr,
        attrs: Expr -> Expr, // expr is {} or hash, should return expr evaluating to html
        for_: Expr -> Expr -> Expr,
        if_: Expr -> Expr -> Expr -> Expr,
        filter: Hash<Expr -> Expr>,
        joinItems: Array<Expr> -> Expr, // this may try to optimize adjecent CString exprs
        quote: Expr -> Expr, // Expr evaluates to str, should return something quoting it
        quoteS: String -> String // quote string for HTML
      }
  ):Expr {
    var r = new ExprBuilder();
    var i = 0;
    var l = ptis.length;
    for(pti in ptis){
      var last = ++i == l;
      switch(pti) {
        case text(s):
          r.s(s);
        case expr(expr, quoted): 
          var e_ = expr;
          if (quoted) e_ = e.quote(e_);
          r.expr(e_);
        case filter(name, expr):
          r.expr(e.filter.get(name)(template_content_to_expr(expr, false, e)));
        case tag(name, attributes, contents, add_space):
          // tag open
          r.s("<"+name);

          for (a in attributes){
            switch(a) {
              case attr_expr(e_): r.expr(e.attrs(e_));
              case attr_name_value(name, value):
                r.s(" ");
                r.s(name+"=\""+e.quoteS(value)+"\"");
              case attr_name_expr_as_value(name, expr):
                r.s(" "+name+"=\"");
                r.expr(e.quote(expr));
                r.s("\"");
            }
          }

          if (ArrayExtensions.contains(autoclose, name)){
            if (contents.length > 0)
              // internal error, should have been caught in parse_tag
              throw "bad, autoclosing tag but contents found!";
            r.s("/>");
          } else {
            r.s(">");
            r.expr(template_content_to_expr(contents, false, e));
            r.s("</"+name+">");
          }
          if (add_space && (!last_no_space || !last))  r.s(" ");
        case control_if(cond, then_, else_):
          r.expr(e.if_(cond, template_content_to_expr(then_, false, e), else_ == null ? null : template_content_to_expr(else_, false, e)));
        case control_for(for_, content ):
          r.expr(e.for_(for_, template_content_to_expr(content, false, e) ));
      }
    }
    return e.joinItems(r.items);
  }
#end

  public static function parse_template(pos, s:String, available_filters: Array<String>):TemplateContent {
    // TODO: introduce caching!
    var ps = { 
       s: s, 
       i:0, 
       pos: pos,
       available_filters: available_filters
    };
    // \n at the beginning? ignore
    if (StringTools.fastCodeAt(ps.s,0) == 10)
      ps.i++;

    var first_line_pos = ps.i;
    while (is_char(" ")) ps.i++;
    var initial_indent = ps.i - first_line_pos;
    ps.i = first_line_pos;
    var r = [];
    parse_template_items(initial_indent, ps, r);
    return r;
  }


#if macro
  public static function template_to_str_expr(pos: {file:String, min:Int, max:Int}, s:String, last_no_space:Bool = true):Expr {
    var filter = new Hash();
    filter.set('javascript', function(e){ return macro "<script type='text/javascript'>//<![CDATA["+$e+ "//]]></script>"; });
    filter.set('css', function(e){ return macro "<style type='text/css'>//<![CDATA["+$e+ "//]]></style>" ; });

    var expr = template_content_to_expr(parse_template(pos, s, mw.HashExtensions.keysAsArray(filter)), last_no_space, {
        filter: filter,
        joinItems: function(items){
                    return switch(items.length) {
                      case 0: macro $v{""};
                      case 1: items[0];
                      case _:
                        var c = items.shift();
                        while (items.length > 0){
                          var next = items.shift();
                          c = macro $c + $next;
                        }
                        c;
                    }
                  },
        quoteS: function(s){ return StringTools.htmlEscape(s); },
        quote: function(e){ return macro StringTools.htmlEscape($e); },
        attrs: function(e){ return macro mw.HTMLTemplate.attrsToHtml($e); },
        if_: function(cond, if_, else_){
                  var el = else_ == null ? (macro "") : else_;
                  return macro ($cond ? $if_ : $el);
              },
        for_: function(for_, content){
            return switch(for_.expr) {
              case EParenthesis(it):
                // var e = {pos: Context.currentPos(), expr: EFor(it, macro s += $content; )}
                macro {
                  var s = "";
                  for ($it)
                    s += $content;
                  s;
                }
              case _: throw "unexpected "+for_.expr;
            }
        }
	// EFor( it : Expr, expr : Expr );
    });

    return expr;
  }
#end

}

/*
  samples see sample at Test.hx
*/
class HTMLTemplate {

#if !macro
  static public function attrsToHtml(a:Dynamic) {
    var s = "";
    if (Std.is(a, Hash)){
      var h: Hash<String> = cast(a);
      for(k in h.keys())
        s+=" "+k+"=\""+ StringTools.htmlEscape(h.get(k))+"\"";
    } else {
      for (k in Reflect.fields(a))
        s+=" "+k+"=\""+ StringTools.htmlEscape(Reflect.field(a,k))+"\"";
    }
    return s;
  }
#end

  @:macro static public function haml_like_str(template:Expr): Expr {
    var e = TemplateParser.template_to_str_expr(Context.getPosInfos(template.pos), ReflectionExtensions.value_at_path(template.expr, ["EConst",0,"CString",0])); 
    return e;
  }
}

