module main

// import parser
import server

fn main() {
	server.run() or {}
	// a := parser.DebugMode{
	// debug: true
	// level: 0
	// }
	// b := a.child()
	// c := b.child()
	//
	// println('hello there')
	//
	// a.log('from a')
	// b.log('from b')
	// c.log('from c')
	//
	// expr := parser.Expr{
	// text: '[1+[1+[1+[10*2]]]]*sin{3}'
	// mode: a
	// }
	//
	// println(expr.parse())
}
