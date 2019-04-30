import 'package:flutter/material.dart';
import '../services/UserService.dart';

class LoginScreen extends StatefulWidget {
  @override
  LoginScreenState createState() => new LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = new GlobalKey<FormState>();
  UserService userService = UserService();

  String _username = "";
  String _password = "";
  String _errorMessage = "";
  bool _isLoading = false;

  bool _validateAndSave() {
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();
      return true;
    }
    return false;
  }

  void _validateAndSubmit() async {
    setState(() {
      _errorMessage = "";
      _isLoading = true;
    });
    if (_validateAndSave()) {
      try {
        if (await userService.login(_username, _password)) {
          Navigator.pushReplacementNamed(context, 'incidentlist');
          _isLoading = false;
        } else {
          setState(() {
            _errorMessage = "Feil ved innlogging - tjeneste ikke tilgjengelig";
          });
        }
      } catch (error) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Widget _showCircularProgress() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    return Container(
      height: 0.0,
      width: 0.0,
    );
  }

  Widget _showEmailInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 30.0, 0.0, 0.0),
      child: new TextFormField(
        maxLines: 1,
        keyboardType: TextInputType.emailAddress,
        autofocus: false,
        decoration: new InputDecoration(
            hintText: 'Brukernavn',
            icon: new Icon(
              Icons.person,
              color: Colors.grey,
            )),
        validator: (value) => value.isEmpty ? 'Brukernavn må fylles ut' : null,
        onSaved: (value) => _username = value,
      ),
    );
  }

  Widget _showPasswordInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
      child: new TextFormField(
        maxLines: 1,
        obscureText: true,
        autofocus: false,
        decoration: new InputDecoration(
            hintText: 'Passord',
            icon: new Icon(
              Icons.lock,
              color: Colors.grey,
            )),
        validator: (value) => value.isEmpty ? 'Passord må fylles ut' : null,
        onSaved: (value) => _password = value,
      ),
    );
  }

  Widget _showPrimaryButton() {
    return new Padding(
        padding: EdgeInsets.fromLTRB(0.0, 25.0, 0.0, 0.0),
        child: SizedBox(
          height: 40.0,
          width: 60.0,
          child: new RaisedButton(
            elevation: 5.0,
            shape: new RoundedRectangleBorder(
                borderRadius: new BorderRadius.circular(10.0)),
            color: Color.fromRGBO(00, 41, 73, 1),
            child: new Text('Logg inn',
                style: new TextStyle(fontSize: 20.0, color: Colors.white)),
            onPressed: () {
              _validateAndSubmit();
            },
          ),
        ));
  }

  Widget _showBody() {
    return new Container(
        padding: EdgeInsets.all(16.0),
        child: new Form(
          key: _formKey,
          child: new ListView(
            shrinkWrap: true,
            children: <Widget>[
              // Logo
              Padding(
                padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 50),
                child: CircleAvatar(
                  backgroundColor: Colors.transparent,
                  radius: 80.0,
                  child: Image.asset('assets/logo.png'),
                ),
              ),
              // Errormessage
              Center(
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                      color: Colors.red,
                      height: 1.0,
                      fontWeight: FontWeight.w300),
                ),
              ),
              _showEmailInput(),
              _showPasswordInput(),
              _showPrimaryButton(),
            ],
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        body: Center(
      child: Container(
        color: Colors.grey,
        alignment: AlignmentDirectional(0.0, 0.0),
        child: Container(
          constraints: BoxConstraints(maxWidth: 400.0),
          child: Card(
            elevation: 10.0,
            child: Stack(
              children: <Widget>[
                _showBody(),
                _showCircularProgress(),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}
